import Flutter
import HealthKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var cachedApnsToken: String?
  private var cachedNotificationTap: [AnyHashable: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Do not request notification permission at launch — Flutter opts in explicitly.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let systemChannel = FlutterMethodChannel(
      name: "com.brogrammers.gotmotionapp/system",
      binaryMessenger: messenger
    )
    systemChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "openHealthApp":
        Self.openHealthApp(result: result)
      case "getHealthMetrics":
        HealthKitDayMetrics.fetch(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let pushChannel = FlutterMethodChannel(
      name: "com.brogrammers.gotmotionapp/push",
      binaryMessenger: messenger
    )
    self.pushChannel = pushChannel
    pushChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "NO_DELEGATE", message: nil, details: nil))
        return
      }
      switch call.method {
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
        if let token = self.cachedApnsToken {
          result(token)
        } else {
          // Token arrives asynchronously via didRegister / onToken.
          result(nil)
        }
      case "unregisterForRemoteNotifications":
        DispatchQueue.main.async {
          UIApplication.shared.unregisterForRemoteNotifications()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if let pending = cachedNotificationTap {
      cachedNotificationTap = nil
      pushChannel.invokeMethod("onNotificationTap", arguments: pending)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    cachedApnsToken = token
    pushChannel?.invokeMethod("onToken", arguments: token)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pushChannel?.invokeMethod("onTokenError", arguments: error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload = response.notification.request.content.userInfo
    if let pushChannel {
      pushChannel.invokeMethod("onNotificationTap", arguments: payload)
    } else {
      cachedNotificationTap = payload
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  private static func openHealthApp(result: @escaping FlutterResult) {
    guard let healthURL = URL(string: "x-apple-health://"),
          UIApplication.shared.canOpenURL(healthURL)
    else {
      result(false)
      return
    }
    UIApplication.shared.open(healthURL, options: [:]) { opened in
      result(opened)
    }
  }
}

/// Apple Watch/iPhone are never added together (duplicate Health samples).
/// Third-party apps that write to Health (MyZone, Garmin, etc.) are added on top.
private enum HealthKitDayMetrics {
  static let store = HKHealthStore()

  static func fetch(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(zeroPayload(standHours: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let startMs = args["startMs"] as? NSNumber,
          let endMs = args["endMs"] as? NSNumber
    else {
      result(
        FlutterError(
          code: "ARG_ERROR",
          message: "startMs and endMs are required",
          details: nil
        )
      )
      return
    }

    let start = Date(timeIntervalSince1970: startMs.doubleValue / 1000.0)
    let end = Date(timeIntervalSince1970: endMs.doubleValue / 1000.0)
    guard end > start else {
      result(zeroPayload(standHours: nil))
      return
    }

    store.requestAuthorization(toShare: nil, read: readTypes) { _, _ in
      loadDay(start: start, end: end, result: result)
    }
  }

  private static var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = [
      HKObjectType.activitySummaryType(),
      HKObjectType.workoutType(),
    ]
    if let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
      types.insert(type)
    }
    if let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
      types.insert(type)
    }
    if let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
      types.insert(type)
    }
    if let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
      types.insert(type)
    }
    if let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
      types.insert(type)
    }
    return types
  }

  private static func loadDay(
    start: Date,
    end: Date,
    result: @escaping FlutterResult
  ) {
    let group = DispatchGroup()
    let lock = NSLock()
    var stepSources = SourceTotals()
    var mileSources = SourceTotals()
    var calorieSources = SourceTotals()
    var minuteSources = SourceTotals()
    var standHours: Double?
    var summary: HKActivitySummary?
    var loggedWorkouts = WorkoutTotals()

    group.enter()
    querySourceTotals(.stepCount, unit: .count(), start: start, end: end) { value in
      lock.lock()
      stepSources = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    querySourceTotals(.distanceWalkingRunning, unit: .mile(), start: start, end: end) { value in
      lock.lock()
      mileSources = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    querySourceTotals(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end) {
      value in
      lock.lock()
      calorieSources = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    querySourceTotals(.appleExerciseTime, unit: .minute(), start: start, end: end) { value in
      lock.lock()
      minuteSources = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    queryStoodHours(start: start, end: end) { value in
      lock.lock()
      standHours = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    queryActivitySummary(day: start) { value in
      lock.lock()
      summary = value
      lock.unlock()
      group.leave()
    }

    group.enter()
    queryLoggedWorkouts(start: start, end: end) { value in
      lock.lock()
      loggedWorkouts = value
      lock.unlock()
      group.leave()
    }

    group.notify(queue: .main) {
      let watchMode =
        stepSources.watch > 0
        || mileSources.watch > 0
        || calorieSources.watch > 0
        || minuteSources.watch > 0

      let steps: Double
      let miles: Double
      if watchMode {
        steps = stepSources.appleOrFallback(watchMode: true)
        miles = mileSources.appleOrFallback(watchMode: true)
      } else {
        // Phone / band / Fitness: take the best Health total so a third-party
        // band isn't ignored when the iPhone also wrote a smaller step count.
        steps = max(stepSources.phone, stepSources.other, stepSources.merged)
        miles = max(mileSources.phone, mileSources.other, mileSources.merged)
      }

      // Re-filter workouts now that we know watch vs phone.
      let workoutTotals = loggedWorkouts.filtered(forWatchMode: watchMode)

      var appleCalories: Double
      var appleMinutes: Double
      var calories: Double
      var minutes: Double

      if watchMode {
        appleCalories = calorieSources.preferredApple(watchMode: true)
        appleMinutes = minuteSources.preferredApple(watchMode: true)
        if let summary {
          appleCalories = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
          appleMinutes = summary.appleExerciseTime.doubleValue(for: .minute())
          standHours = summary.appleStandHours.doubleValue(for: .count())
        }
        // Watch users: ring minutes from Watch; add third-party workouts only.
        let thirdPartyCalories = max(calorieSources.other, workoutTotals.kilocalories)
        calories = appleCalories + thirdPartyCalories
        minutes = appleMinutes + workoutTotals.minutes
      } else {
        // Phone-only: match what Apple Health shows. Exercise minutes can come
        // from the iPhone, Fitness, or apps writing appleExerciseTime — not only
        // a source labeled "iPhone". Prefer Health's merged totals.
        appleCalories = max(
          calorieSources.phone,
          calorieSources.other,
          calorieSources.merged
        )
        appleMinutes = max(
          minuteSources.phone,
          minuteSources.other,
          minuteSources.merged
        )
        // Workouts may add duration/energy that isn't fully in those totals.
        calories = max(appleCalories, workoutTotals.kilocalories)
        minutes = max(appleMinutes, workoutTotals.minutes)
      }

      var payload: [String: Any] = [
        "steps": steps,
        "miles": miles,
        "calories": calories,
        "exerciseMinutes": minutes,
        "source": watchMode ? "watch" : "phone",
      ]
      if let standHours {
        payload["standHours"] = standHours
      }
      result(payload)
    }
  }

  private static func querySourceTotals(
    _ identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    completion: @escaping (SourceTotals) -> Void
  ) {
    guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
      completion(SourceTotals())
      return
    }
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )
    let query = HKStatisticsQuery(
      quantityType: type,
      quantitySamplePredicate: predicate,
      options: [.cumulativeSum, .separateBySource]
    ) { _, stats, _ in
      completion(SourceTotals.from(stats, unit: unit))
    }
    store.execute(query)
  }

  /// Loads HealthKit workouts (Apple/iPhone + third-party). Callers filter via
  /// [WorkoutTotals.filtered] so Watch users don't double-count the green ring.
  private static func queryLoggedWorkouts(
    start: Date,
    end: Date,
    completion: @escaping (WorkoutTotals) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      guard let workouts = samples as? [HKWorkout] else {
        completion(WorkoutTotals())
        return
      }
      var applePhone = WorkoutTotals()
      var thirdParty = WorkoutTotals()
      for workout in workouts {
        let blob =
          "\(workout.sourceRevision.source.bundleIdentifier) \(workout.sourceRevision.source.name)"
          .lowercased()
        let clippedStart = max(workout.startDate, start)
        let clippedEnd = min(workout.endDate, end)
        guard clippedEnd > clippedStart else { continue }
        let minutes = clippedEnd.timeIntervalSince(clippedStart) / 60.0
        let kilocalories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        let isWatch = blob.contains("watch")
        let isApplePhone =
          !isWatch
          && (blob.contains("iphone")
            || blob.contains("phone")
            || blob.contains("com.apple"))
        if isWatch {
          continue
        }
        if isApplePhone {
          applePhone.minutes += minutes
          applePhone.kilocalories += kilocalories
        } else {
          thirdParty.minutes += minutes
          thirdParty.kilocalories += kilocalories
        }
      }
      // Store both buckets; filtered(forWatchMode:) picks the right mix.
      completion(
        WorkoutTotals(
          minutes: applePhone.minutes + thirdParty.minutes,
          kilocalories: applePhone.kilocalories + thirdParty.kilocalories,
          applePhoneMinutes: applePhone.minutes,
          applePhoneKilocalories: applePhone.kilocalories,
          thirdPartyMinutes: thirdParty.minutes,
          thirdPartyKilocalories: thirdParty.kilocalories
        )
      )
    }
    store.execute(query)
  }

  private static func queryActivitySummary(
    day: Date,
    completion: @escaping (HKActivitySummary?) -> Void
  ) {
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: day)
    components.calendar = calendar
    let predicate = HKQuery.predicateForActivitySummary(with: components)
    let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
      completion(summaries?.first)
    }
    store.execute(query)
  }

  private static func queryStoodHours(
    start: Date,
    end: Date,
    completion: @escaping (Double?) -> Void
  ) {
    guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else {
      completion(nil)
      return
    }
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, _ in
      guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
        completion(nil)
        return
      }
      let calendar = Calendar.current
      var hours = Set<Int>()
      for sample in samples
        where sample.value == HKCategoryValueAppleStandHour.stood.rawValue
      {
        let parts = calendar.dateComponents(
          [.year, .month, .day, .hour],
          from: sample.startDate
        )
        hours.insert(
          (parts.year ?? 0) * 1_000_000
            + (parts.month ?? 0) * 10_000
            + (parts.day ?? 0) * 100
            + (parts.hour ?? 0)
        )
      }
      completion(Double(hours.count))
    }
    store.execute(query)
  }

  private static func zeroPayload(standHours: Double?) -> [String: Any] {
    var payload: [String: Any] = [
      "steps": 0.0,
      "miles": 0.0,
      "calories": 0.0,
      "exerciseMinutes": 0.0,
      "source": "phone",
    ]
    if let standHours {
      payload["standHours"] = standHours
    }
    return payload
  }
}

private struct WorkoutTotals {
  var minutes = 0.0
  var kilocalories = 0.0
  var applePhoneMinutes = 0.0
  var applePhoneKilocalories = 0.0
  var thirdPartyMinutes = 0.0
  var thirdPartyKilocalories = 0.0

  /// Watch mode: third-party only (Watch rings already cover Apple activity).
  /// Phone-only: include iPhone / Fitness / Health-logged workouts too.
  func filtered(forWatchMode watchMode: Bool) -> WorkoutTotals {
    if watchMode {
      return WorkoutTotals(
        minutes: thirdPartyMinutes,
        kilocalories: thirdPartyKilocalories,
        thirdPartyMinutes: thirdPartyMinutes,
        thirdPartyKilocalories: thirdPartyKilocalories
      )
    }
    return WorkoutTotals(
      minutes: applePhoneMinutes + thirdPartyMinutes,
      kilocalories: applePhoneKilocalories + thirdPartyKilocalories,
      applePhoneMinutes: applePhoneMinutes,
      applePhoneKilocalories: applePhoneKilocalories,
      thirdPartyMinutes: thirdPartyMinutes,
      thirdPartyKilocalories: thirdPartyKilocalories
    )
  }
}

/// Watch wins over iPhone when it recorded anything. Third-party sources are summed separately.
private struct SourceTotals {
  var watch = 0.0
  var phone = 0.0
  var other = 0.0
  var merged = 0.0

  static func from(_ stats: HKStatistics?, unit: HKUnit) -> SourceTotals {
    guard let stats else { return SourceTotals() }
    var totals = SourceTotals()
    totals.merged = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
    for source in stats.sources ?? [] {
      let value = stats.sumQuantity(for: source)?.doubleValue(for: unit) ?? 0
      let blob = "\(source.bundleIdentifier) \(source.name)".lowercased()
      if blob.contains("watch") {
        totals.watch = max(totals.watch, value)
      } else if blob.contains("iphone") || blob.contains("phone") {
        totals.phone = max(totals.phone, value)
      } else {
        totals.other += value
      }
    }
    return totals
  }

  func preferredApple(watchMode: Bool) -> Double {
    if watchMode { return watch }
    // Phone path: Health may attribute samples to "Health" / apps, not "iPhone".
    if phone > 0 { return phone }
    if other > 0 { return other }
    return merged
  }

  func appleOrFallback(watchMode: Bool) -> Double {
    let apple = preferredApple(watchMode: watchMode)
    if apple > 0 { return apple }
    if other > 0 { return other }
    return merged
  }
}
