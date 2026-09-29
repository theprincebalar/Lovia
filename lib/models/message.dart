import 'emotion_state.dart';

class ChatMessage {
  final String id;
  final String characterId;
  final bool isUser;
  final String content;
  final EmotionState emotion;
  final DateTime timestamp;
  final bool isVoiceMessage;

  ChatMessage({
    required this.id,
    required this.characterId,
    required this.isUser,
    required this.content,
    this.emotion = EmotionState.happy,
    DateTime? timestamp,
    this.isVoiceMessage = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Extract text spoken aloud (strip roleplay action asterisks and meta tags)
  String get speechText {
    final clean = content
        .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\*[^*]*\*'), '')
        .replaceAll(RegExp(r'""+'), '"')
        .replaceAll('"', '')
        .trim();
    return clean.isEmpty ? content.replaceAll('*', '').replaceAll('"', '') : clean;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'characterId': characterId,
    'isUser': isUser,
    'content': content,
    'emotion': emotion.name,
    'timestamp': timestamp.toIso8601String(),
    'isVoiceMessage': isVoiceMessage,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String rawContent = json['content'] as String? ?? '';
    // Automatically cleanse any historical leaked prompt tags or duplicate quotes
    rawContent = rawContent
        .replaceAll(RegExp(r'\[EMOTION[^\]\n]*\]?', caseSensitive: false), '')
        .replaceAll(RegExp(r'""+'), '"')
        .trim();
    // If quote was opened but unclosed due to legacy truncation, close it
    if (rawContent.startsWith('"') && !rawContent.endsWith('"')) {
      rawContent = '$rawContent"';
    }
    return ChatMessage(
      id: json['id'] as String,
      characterId: json['characterId'] as String,
      isUser: json['isUser'] as bool,
      content: rawContent,
      emotion: EmotionState.fromString(json['emotion'] as String? ?? 'happy'),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isVoiceMessage: json['isVoiceMessage'] as bool? ?? false,
    );
  }
}
