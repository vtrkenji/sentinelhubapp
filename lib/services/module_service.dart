import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/hardware_module.dart';

class ModuleService {
  static const _modulesKey = 'hardware_modules_list';
  final _uuid = const Uuid();

  Future<List<HardwareModule>> getModules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_modulesKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => HardwareModule.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> _saveModules(List<HardwareModule> modules) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(modules.map((m) => m.toJson()).toList());
    await prefs.setString(_modulesKey, jsonString);
  }

  Future<HardwareModule> addModule(HardwareModule module) async {
    final modules = await getModules();
    final newModule = module.copyWith(id: _uuid.v4());
    modules.add(newModule);
    await _saveModules(modules);
    return newModule;
  }

  Future<void> updateModule(HardwareModule module) async {
    final modules = await getModules();
    final index = modules.indexWhere((m) => m.id == module.id);
    if (index != -1) {
      modules[index] = module;
      await _saveModules(modules);
    }
  }

  Future<void> removeModule(String id) async {
    final modules = await getModules();
    modules.removeWhere((m) => m.id == id);
    await _saveModules(modules);
  }
}
