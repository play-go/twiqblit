import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  void setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String> getString(String key, String defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? defaultValue;
  }

  void setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<int> getInt(String key, int defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  void setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  void setDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<double> getDouble(String key, double defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(key) ?? defaultValue;
  }

  void setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  Future<List<String>> getStringList(String key, List<String> defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? defaultValue;
  }

  void remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
  
  Future<bool> contains(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }
}
