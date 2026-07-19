import 'package:exploding_kittens/network/websocket/websocket_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WsMessage — serialización round-trip', () {
    void roundTrip(WsMessage msg) {
      final restored = WsMessage.fromJson(msg.toJson());
      expect(restored.toJson(), equals(msg.toJson()));
    }

    // ── client → server ────────────────────────────────────────────────────
    test('JoinRoomMessage sin token (primer join)', () {
      roundTrip(const JoinRoomMessage(playerId: 'p1', name: 'Alice'));
    });

    test('JoinRoomMessage.toJson omite token cuando es null', () {
      const msg = JoinRoomMessage(playerId: 'p1', name: 'Alice');
      expect(msg.toJson().containsKey('token'), isFalse);
    });

    test('JoinRoomMessage con token (reconexión)', () {
      roundTrip(
        const JoinRoomMessage(playerId: 'p1', name: 'Alice', token: 'tok-123'),
      );
    });

    test('SetReadyMessage true/false', () {
      roundTrip(const SetReadyMessage(ready: true));
      roundTrip(const SetReadyMessage(ready: false));
    });

    test('LeaveRoomMessage', () {
      roundTrip(const LeaveRoomMessage(playerId: 'p1'));
    });

    test('StartGameMessage', () {
      roundTrip(const StartGameMessage());
    });

    // ── server → client ────────────────────────────────────────────────────
    test('RoomStateMessage conserva roomJson', () {
      const payload = {'id': 'room1', 'hostId': 'h1'};
      final msg = RoomStateMessage(roomJson: payload);
      final restored = WsMessage.fromJson(msg.toJson()) as RoomStateMessage;
      expect(restored.roomJson, equals(payload));
    });

    test('SessionTokenMessage', () {
      roundTrip(const SessionTokenMessage(token: 'tok-123'));
    });

    test('GameStartingMessage', () {
      roundTrip(const GameStartingMessage());
    });

    test('PlayerKickedMessage', () {
      roundTrip(const PlayerKickedMessage(reason: 'Host left'));
    });

    test('WsErrorMessage', () {
      roundTrip(const WsErrorMessage(message: 'Room is full'));
    });

    // ── heartbeat ──────────────────────────────────────────────────────────
    test('PingMessage / PongMessage', () {
      roundTrip(const PingMessage());
      roundTrip(const PongMessage());
    });

    // ── in-game (Fase 5) ───────────────────────────────────────────────────
    test('GameStateMessage conserva payload', () {
      final msg = GameStateMessage(stateJson: {'turn': 1});
      final restored = WsMessage.fromJson(msg.toJson()) as GameStateMessage;
      expect(restored.stateJson, equals({'turn': 1}));
    });

    test('ActionMessage conserva payload', () {
      final msg = ActionMessage(actionJson: {'type': 'draw'});
      final restored = WsMessage.fromJson(msg.toJson()) as ActionMessage;
      expect(restored.actionJson, equals({'type': 'draw'}));
    });

    test('PlayerReconnectedMessage', () {
      roundTrip(const PlayerReconnectedMessage(playerId: 'p2'));
    });

    test('GameEventMessage conserva payload', () {
      final msg = GameEventMessage(eventJson: {'type': 'card_drawn'});
      final restored = WsMessage.fromJson(msg.toJson()) as GameEventMessage;
      expect(restored.eventJson, equals({'type': 'card_drawn'}));
    });

    test('ActionRejectedMessage', () {
      roundTrip(const ActionRejectedMessage(message: 'no es tu turno'));
    });

    // ── tipo desconocido ────────────────────────────────────────────────────
    test('fromJson lanza FormatException en tipo desconocido', () {
      expect(
        () => WsMessage.fromJson({'type': 'unknown_xyz'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
