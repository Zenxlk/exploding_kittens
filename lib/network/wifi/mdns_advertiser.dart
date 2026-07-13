import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/core/errors/failures.dart';

import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';

// Anuncia una sala en la red local vía UDP broadcast.
//
// Cada [interval] se manda un beacon JSON a 255.255.255.255:[discoveryPort]
// para que las instancias de MdnsDiscoverer en la misma subred la encuentren.
//
// TODO(improvement): reemplazar por el paquete `nsd` (pub.dev/packages/nsd)
// para un registro mDNS/DNS-SD real que aparezca en los navegadores de
// servicios del sistema y funcione con Apple Bonjour.
//
// TODO(improvement): en Android 10+, recibir UDP broadcast requiere
// adquirir un WifiManager.MulticastLock vía platform channel. Agregarlo
// antes de publicar en la Play Store.
class MdnsAdvertiser {
  RawDatagramSocket? _socket;
  Timer? _timer;
  DiscoveredRoom? _room;
  int _discoveryPort = AppConstants.discoveryPort;
  bool get isRunning => _socket != null;

  // Empieza a transmitir el beacon de la sala. Lanza [NetworkFailure] si el
  // dispositivo no está conectado a WiFi. [discoveryPort] es el puerto UDP
  // al que se mandan los beacons — sobreescribible para que los tests usen
  // el suyo propio y no choquen con otros archivos de test que usan el real.
  Future<void> start({
    required String roomId,
    required String hostName,
    required int playerCount,
    required int maxPlayers,
    int port = AppConstants.localGamePort,
    int discoveryPort = AppConstants.discoveryPort,
    Duration interval = const Duration(seconds: 3),
  }) async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null) {
      throw const NetworkFailure('Could not determine WiFi IP address');
    }

    _discoveryPort = discoveryPort;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    _room = DiscoveredRoom(
      roomId: roomId,
      hostName: hostName,
      hostAddress: ip,
      port: port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );

    _sendBeacon(_room!);
    // Lee _room actualizado en cada tick (no un valor capturado una sola
    // vez acá) para que los cambios de updatePlayerCount se mantengan —
    // antes esto seguía anunciando el playerCount con el que arrancó la
    // sala, pisando el beacon de updatePlayerCount cada `interval`.
    _timer = Timer.periodic(interval, (_) {
      final room = _room;
      if (room != null) _sendBeacon(room);
    });
  }

  // Llamar cada vez que cambie la cantidad de jugadores para que quien
  // escucha vea datos frescos.
  Future<void> updatePlayerCount({
    required int playerCount,
    required int maxPlayers,
  }) async {
    final current = _room;
    if (current == null || _socket == null) return;

    final ip = await NetworkInfo().getWifiIP() ?? current.hostAddress;
    _room = DiscoveredRoom(
      roomId: current.roomId,
      hostName: current.hostName,
      hostAddress: ip,
      port: current.port,
      playerCount: playerCount,
      maxPlayers: maxPlayers,
    );
    _sendBeacon(_room!);
  }

  void _sendBeacon(DiscoveredRoom room) {
    if (_socket == null) return;
    try {
      final payload = utf8.encode(jsonEncode(room.toJson()));
      _socket!.send(
        payload,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _timer = null;
    _socket = null;
    _room = null;
  }
}
