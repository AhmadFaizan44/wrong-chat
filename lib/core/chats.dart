import 'dart:math';
import 'dart:ui' show Color;

/// One chat the player can send to. Each is a column (lane) in the dock at the bottom of the screen.
class Chat {
  const Chat({required this.id, required this.name, required this.avatar, required this.color, required this.happy, required this.confused});
  final String id;
  final String name;
  final String avatar;
  final Color color;

  /// Reaction when the right message arrives, and when the wrong one does.
  final List<String> happy;
  final List<String> confused;
}

class Chats {
  static const mom = Chat(
    id: 'mom',
    name: 'Mom',
    avatar: '👩',
    color: Color(0xFFFF9F43),
    happy: ['❤️', '🥰', '👍', 'ok dear'],
    confused: ['who is this??', '🤨', 'call me NOW', 'excuse me?!'],
  );
  static const boss = Chat(
    id: 'boss',
    name: 'Boss',
    avatar: '💼',
    color: Color(0xFF4DA3FF),
    happy: ['👍', 'noted.', 'great work', '✅'],
    confused: ['my office. now.', '🤨', '...???', 'HR has been cc\'d'],
  );
  static const crush = Chat(
    id: 'crush',
    name: 'Crush',
    avatar: '😍',
    color: Color(0xFFFF5FA2),
    happy: ['😳', '🥺💕', 'hehe', '😊'],
    confused: ['uh... ok?', '😐', 'wrong person?', 'left on read'],
  );
  static const squad = Chat(
    id: 'squad',
    name: 'Squad',
    avatar: '🎉',
    color: Color(0xFF3DDC97),
    happy: ['😂😂', 'LMAO', '🔥', 'real'],
    confused: ['SCREENSHOTTED 📸', '💀💀💀', 'bro what', 'pinned this 📌'],
  );

  /// Chats in the order they join the dock. The first three are there from the start.
  static const all = [mom, boss, crush, squad];
  static const startLanes = 3;

  /// The 4th chat (Squad) joins after this many correct sends in a run.
  static const squadUnlockAt = 10;
}

/// A text the player is trying to send. [to] is the only chat it makes sense in.
class Msg {
  const Msg(this.text, this.to);
  final String text;
  final String to;
}

/// Every message is written so that only one chat fits it. Shown in "How to play" so players can see the rules.
const Map<String, List<String>> messageBank = {
  'mom': [
    'yes I ate 🍲',
    'home by 10, promise 🏠',
    'can u send money? 💸',
    'love you mum ❤️',
    'what\'s the wifi password 📶',
    'I didn\'t break the vase 🏺',
    'is dinner ready? 🍝',
    'sorry I forgot to call 📞',
    'can I borrow the car? 🚗',
    'happy birthday mum 🎂',
    'yes I\'m wearing a jacket 🧥',
    'tell grandma I said hi 👵',
    'where\'s my charger?? 🔌',
    'I cleaned my room 🧹 (mostly)',
  ],
  'boss': [
    'report attached 📊',
    'running 5 min late 🚗',
    'per my last email…',
    'I\'ll circle back 🔄',
    'feeling sick today 🤒',
    'meeting moved to 3pm 📅',
    'can I get Friday off? 🏖️',
    'slides are ready 📈',
    'on it! 💼',
    'let\'s sync tomorrow 🗓️',
    'invoice sent 🧾',
    'quick question re: Q3 📉',
    'deadline extension? 🙏',
    'joining the call now 💻',
  ],
  'crush': [
    'can\'t stop thinking about u 🥺',
    'wanna get pizza sometime? 🍕💕',
    'you looked cute today 😳',
    'goodnight ✨🌙',
    'so... what are we? 👉👈',
    'saw this and thought of u 🌹',
    'miss you already 💕',
    'is that my hoodie? 😍',
    'ur smile is illegal 😵‍💫',
    'save me a seat? 💘',
    'I wrote u a song 🎸💞',
    'dream about me 😴💗',
  ],
  'squad': [
    'LMAOOO 😂',
    'who\'s bringing snacks? 🍿',
    'meme dump incoming 🐸',
    'game night?? 🎮',
    '@everyone vote now 🗳️',
    'no spoilers pls 🙈',
    'this you? 💀',
    'brb 🏃',
    'pizza party at mine 🍕🎉',
    'who ate my fries 🍟😤',
    'group pic when?? 📸',
    'squad goals fr 🔥',
  ],
};

/// Picks messages fairly: each chat has its own shuffled deck, so no line repeats until its deck runs out.
class MessageDeck {
  MessageDeck(this._rng);
  final Random _rng;
  final Map<String, List<String>> _decks = {};

  Msg draw(String chatId) {
    final deck = _decks.putIfAbsent(chatId, () => []);
    if (deck.isEmpty) deck.addAll(List.of(messageBank[chatId]!)..shuffle(_rng));
    return Msg(deck.removeLast(), chatId);
  }
}
