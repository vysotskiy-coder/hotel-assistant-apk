import '../models/room.dart';
import '../models/hotel_area.dart';

List<Room> rooms = [
  // =========================
  // Haupthotel (1–10)
  // =========================
  Room(number: 1, area: HotelArea.mainHotel),
  Room(number: 2, area: HotelArea.mainHotel),
  Room(number: 3, area: HotelArea.mainHotel),
  Room(number: 4, area: HotelArea.mainHotel),
  Room(number: 5, area: HotelArea.mainHotel),
  Room(number: 6, area: HotelArea.mainHotel),
  Room(number: 7, area: HotelArea.mainHotel),
  Room(number: 8, area: HotelArea.mainHotel),
  Room(number: 9, area: HotelArea.mainHotel),
  Room(number: 10, area: HotelArea.mainHotel),

  // =========================
  // Untergeschoss (1–5)
  // =========================
  Room(number: 1, area: HotelArea.basement),
  Room(number: 2, area: HotelArea.basement),
  Room(number: 3, area: HotelArea.basement),
  Room(number: 4, area: HotelArea.basement),
  Room(number: 5, area: HotelArea.basement),

  // =========================
  // Ferienwohnung
  // =========================
  Room(number: 1, area: HotelArea.apartment),
];
