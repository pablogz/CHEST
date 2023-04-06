class Config {
  //TODO
  static const String addServer = 'http://192.168.1.200:11110';
  // static const String addServer = 'http://10.0.104.17:11110';
  // static const String addServer = 'http://10.1.104.9:11110';
  // static const String addServer = 'http://192.168.178.127:11110';
  // static const String addServer = 'http://192.168.137.127:11110';
  // static const String addServer = 'http://192.168.1.63:11110';
  //static const String addServer = 'http://127.0.0.1:11110';
  // static const String addServer = 'https://chest.gsic.uva.es/server';
  static const bool debug = addServer != 'https://chest.gsic.uva.es/server';

//TODO Only for CHEST!!
  static const String tokenMapbox =
      'pk.eyJ1IjoicGFibG9neiIsImEiOiJja3ExMWcxajQwMTN4MnVsYTJtMmdpOXc2In0.S9rtoLY8TYoI-4D8oy8F8A';
}
