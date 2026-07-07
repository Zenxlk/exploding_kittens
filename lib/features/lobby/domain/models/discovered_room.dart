import 'package:equatable/equatable.dart';

// A room found on the local network by MdnsDiscoverer.
class DiscoveredRoom extends Equatable {
  const DiscoveredRoom({
    required this.roomId,
    required this.hostName,
    required this.hostAddress,
    required this.port,
    required this.playerCount,
    required this.maxPlayers,
  });

  final String roomId;
  final String hostName;

  // IPv4 address of the host device on the local network.
  final String hostAddress;
  final int port;
  final int playerCount;
  final int maxPlayers;

  bool get isFull => playerCount >= maxPlayers;

  Map<String, dynamic> toJson() => {
        'type': 'room_beacon',
        'roomId': roomId,
        'hostName': hostName,
        'hostAddress': hostAddress,
        'port': port,
        'playerCount': playerCount,
        'maxPlayers': maxPlayers,
      };

  factory DiscoveredRoom.fromJson(Map<String, dynamic> j) => DiscoveredRoom(
        roomId: j['roomId'] as String,
        hostName: j['hostName'] as String,
        hostAddress: j['hostAddress'] as String,
        port: j['port'] as int,
        playerCount: j['playerCount'] as int,
        maxPlayers: j['maxPlayers'] as int,
      );

  @override
  List<Object?> get props =>
      [roomId, hostName, hostAddress, port, playerCount, maxPlayers];
}
