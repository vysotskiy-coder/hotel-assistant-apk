enum AppLanguage { german, russian }

class AppStrings {
  final AppLanguage language;

  AppStrings(this.language);

  bool get isGerman => language == AppLanguage.german;

  String get appTitle => isGerman ? 'Hotel Assistant' : 'Помощник отеля';

  String get owner => isGerman ? 'Besitzer' : 'Владелец';

  String get housemaster => isGerman ? 'Hausmeister' : 'Хаусмастер';

  String get mainHotel => isGerman ? 'Haupthotel' : 'Основной отель';

  String get basement => isGerman ? 'Untergeschoss' : 'Подвал';

  String get apartment => isGerman ? 'Ferienwohnung' : 'Квартира';

  String get rooms1to10 => isGerman ? 'Zimmer 1–10' : 'Комнаты 1–10';

  String get rooms1to5 => isGerman ? 'Zimmer 1–5' : 'Комнаты 1–5';

  String get guestApartment => isGerman ? 'Gästewohnung' : 'Гостевая квартира';
}
