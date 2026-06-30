class ApiConfig {
  // Centralized Domain Configuration
  static const String domain = "agnicarrental.com";

  // Base URLs
  static const String baseUrl = "https://$domain";
  static const String wwwBaseUrl = "https://www.$domain";

  // Service Subpaths
  static const String driverPath = "$baseUrl/driver2025";
  static const String whatsappPath = "$baseUrl/whatsapp_trips";
  static const String wwwWhatsappPath = "$wwwBaseUrl/whatsapp_trips";
  static const String wwwEventPath = "$wwwBaseUrl/agni_event_duty";
  static const String legacyPath = "$baseUrl/2025";

  // Endpoints under driver2025
  static const String acceptBooking = "$driverPath/acceptBooking.php";
  static const String cancelBooking = "$driverPath/cancelBooking.php";
  static const String carDocumentExpiredList = "$driverPath/car_document_expaired_list.php";
  static const String carDriverSelectionPage = "$driverPath/car_driver_selction_page.php";
  static const String carListForVendor = "$driverPath/car_list_for_vender.php";
  static const String changeDocumentExpiredDate = "$driverPath/change_document_expaired_date.php";
  static const String checkPhone = "$baseUrl/admin2025/partner/checkPhone_fixed.php";
  static const String driverCodeFetching = "$driverPath/driver_code_fetching.php";
  static const String driverDetailsFetching = "$driverPath/driver_details_fetching.php";
  static const String driverListForVendor = "$driverPath/driver_list_for_vender.php";
  static const String driversDocumentExpiredList = "$driverPath/drivers_document_expaired_list.php";
  static const String getBookingsForDriver = "$driverPath/get_bookings_for_driver.php";
  static const String getAppVersion = "$driverPath/getAppVersion.php";
  static const String getBookings = "$driverPath/getBookings.php";
  static const String getCarCategories = "$driverPath/get_car_categories.php";
  static const String getCompletedListForDriver = "$driverPath/getCompleatedListForDriver.php";
  static const String getCompletedListForVendor = "$driverPath/getCompleatedListForVender.php";
  static const String registerCar = "$driverPath/register_car.php";
  static const String registerDriver = "$driverPath/register_driver.php";
  static const String regStatusCheck = "$driverPath/regStatusCheck.php";
  static const String saveStartingKm = "$driverPath/save_starting_km.php";
  static const String saveDriverPhone = "$baseUrl/admin2025/partner/saveDriverPhone_fixed.php";
  static const String statusChangeFilled = "$driverPath/status_change_filled.php";
  static const String statusChangeNotJoin = "$driverPath/status_change_not_join.php";
  static const String statusChangeNotFilled = "$driverPath/status_change_notFilled.php";
  static const String submitCarDriverSelectionPage = "$driverPath/submit_car_driver_selction_page.php";
  static const String tripLiveMappingBackend = "$driverPath/trip_live_mapping_backend.php";
  static const String updateEndTripDetails = "$driverPath/update_endTrip_Details.php";
  static const String updateFcmToken = "$driverPath/update_fcm_token.php";
  static const String updateLocation = "$driverPath/update_location.php";

  // Assets
  static const String add1Webp = "$driverPath/add/add1.webp";
  static const String add2Webp = "$driverPath/add/add2.webp";
  static const String add3Webp = "$driverPath/add/add3.webp";
  static const String add4Webp = "$driverPath/add/add4.webp";
  static const String trakonPng = "$driverPath/add/trakon_2.png";

  // Endpoints under whatsapp_trips
  static const String alertMessage = "$whatsappPath/alert_message.php";
  static const String balanceCheck = "$whatsappPath/balance_check.php";
  static const String driverAlertMessageUpdate = "$whatsappPath/driver_alert_message_update.php";
  static const String driverWhatsappCallOnOff = "$whatsappPath/driver_whatsapp_call_on_off.php";
  static const String payment = "$whatsappPath/payment.php";
  static const String whatsappMsgClickCounter = "$whatsappPath/whatsapp_msg_click_counter.php";
  static const String vendorTrips = "$wwwWhatsappPath/vendor_trips.php";
  static const String whatsappTrips = "$wwwWhatsappPath/whatsapp_trips.php";

  // Endpoints under agni_event_duty
  static const String passengerBooking = "$wwwEventPath/passenger_booking.php";

  // Endpoints under 2025
  static const String getInvoiceData = "$legacyPath/get_invoice_data.php/get_invoice_data.php";
  static const String selectCarCostList = "$legacyPath/selectCarCostList.php";
  static const String getSettlements = "$legacyPath/get_settlements.php";
  static const String getCancelledBookings = "$legacyPath/getCancelledBookingsForVendor.php";

  // Third party (routed through our server to support both SMS and WhatsApp OTPs)
  static const String fast2smsUrl = "$baseUrl/2025/send_otp.php";
}
