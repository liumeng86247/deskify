import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 下载任务状态
enum DownloadStatus {
  pending,    // 等待中
  running,    // 下载中
  success,    // 成功
  failed,     // 失败
  canceled,   // 已取消
}

/// 下载任务模型
class DownloadTask {
  final String id;
  final Uri url;
  final String fileName;
  String? savePath;
  int receivedBytes;
  int? totalBytes;
  DownloadStatus status;
  String? error;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.savePath,
    this.receivedBytes = 0,
    this.totalBytes,
    this.status = DownloadStatus.pending,
    this.error,
  });

  /// 获取下载进度（0-1）
  double get progress {
    if (totalBytes == null || totalBytes == 0) return 0;
    return receivedBytes / totalBytes!;
  }

  /// 格式化文件大小
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedSize {
    if (totalBytes == null) {
      return '${formatBytes(receivedBytes)} / 未知';
    }
    return '${formatBytes(receivedBytes)} / ${formatBytes(totalBytes!)}';
  }
}

/// 下载管理服务
class DownloadService extends ChangeNotifier {
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, http.Client> _clients = {};

  List<DownloadTask> get tasks => _tasks.values.toList();

  DownloadTask? getTask(String id) => _tasks[id];

  /// 判断文件扩展名是否需要下载确认（可执行文件）
  static bool isExecutableFile(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ['.exe', '.bat', '.cmd', '.sh', '.ps1', '.msi', '.app'].contains(ext);
  }

  /// 从 URL 提取文件名
  static String getFileNameFromUrl(Uri url) {
    String fileName = path.basename(url.path);
    if (fileName.isEmpty || !fileName.contains('.')) {
      fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }
    return fileName;
  }

  /// 获取唯一的文件保存路径（避免重名）
  Future<String> _getUniqueFilePath(String directory, String fileName) async {
    String baseName = path.basenameWithoutExtension(fileName);
    String extension = path.extension(fileName);
    String filePath = path.join(directory, fileName);

    int counter = 1;
    while (await File(filePath).exists()) {
      filePath = path.join(directory, '$baseName($counter)$extension');
      counter++;
    }

    return filePath;
  }

  /// 添加下载任务
  Future<String> enqueue(Uri url, {String? customFileName}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = customFileName ?? getFileNameFromUrl(url);

    // 获取下载目录
    Directory? downloadsDir;
    try {
      downloadsDir = await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('❌ 获取下载目录失败: $e');
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final savePath = await _getUniqueFilePath(downloadsDir.path, fileName);

    final task = DownloadTask(
      id: id,
      url: url,
      fileName: path.basename(savePath),
      savePath: savePath,
    );

    _tasks[id] = task;
    notifyListeners();

    // 开始下载
    _startDownload(id);

    return id;
  }

  /// 开始下载
  Future<void> _startDownload(String id) async {
    final task = _tasks[id];
    if (task == null) return;

    task.status = DownloadStatus.running;
    notifyListeners();

    try {
      final client = http.Client();
      _clients[id] = client;

      final request = http.Request('GET', task.url);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      task.totalBytes = response.contentLength;
      notifyListeners();

      final file = File(task.savePath!);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        if (task.status == DownloadStatus.canceled) {
          await sink.close();
          await file.delete();
          return;
        }

        sink.add(chunk);
        task.receivedBytes += chunk.length;
        notifyListeners();
      }

      await sink.close();

      task.status = DownloadStatus.success;
      debugPrint('✅ 下载成功: ${task.fileName} -> ${task.savePath}');
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      debugPrint('❌ 下载失败 [${task.fileName}]: $e');
    } finally {
      _clients.remove(id)?.close();
      notifyListeners();
    }
  }

  /// 取消下载
  void cancel(String id) {
    final task = _tasks[id];
    if (task == null) return;

    task.status = DownloadStatus.canceled;
    _clients[id]?.close();
    _clients.remove(id);
    notifyListeners();

    debugPrint('🚫 下载已取消: ${task.fileName}');
  }

  /// 删除任务
  void removeTask(String id) {
    cancel(id);
    _tasks.remove(id);
    notifyListeners();
  }

  /// 打开文件所在文件夹
  Future<void> openFileLocation(String id) async {
    final task = _tasks[id];
    if (task?.savePath == null) return;

    try {
      final directory = path.dirname(task!.savePath!);
      if (Platform.isWindows) {
        await Process.run('explorer', [directory]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [directory]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      debugPrint('❌ 打开文件夹失败: $e');
    }
  }

  /// 清除所有已完成/失败的任务
  void clearCompleted() {
    _tasks.removeWhere((id, task) =>
        task.status == DownloadStatus.success ||
        task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.canceled);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var client in _clients.values) {
      client.close();
    }
    _clients.clear();
    super.dispose();
  }
}
