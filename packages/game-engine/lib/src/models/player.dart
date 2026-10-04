import 'card.dart';

enum PlayerStatus { ACTIVE, DROPPED, DECLARED, DISCONNECTED }

class Player {
  final String id;
  List<Card> hand;
  int score;
  PlayerStatus status;

  Player({
    required this.id,
    List<Card>? hand,
    this.score = 0,
    this.status = PlayerStatus.ACTIVE,
  }) : hand = hand ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'hand': hand.map((c) => c.toInt()).toList(),
        'score': score,
        'status': status.name,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'],
        hand: (json['hand'] as List).map((val) => Card.fromInt(val)).toList(),
        score: json['score'],
        status: PlayerStatus.values.byName(json['status']),
      );
}
