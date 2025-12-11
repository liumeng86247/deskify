import 'package:flutter/material.dart';
import '../services/download_service.dart';

/// 下载管理对话框
class DownloadDialog extends StatelessWidget {
  final DownloadService downloadService;

  const DownloadDialog({
    super.key,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                const Icon(Icons.download, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  '下载管理器',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: '关闭',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 任务列表
            Expanded(
              child: ListenableBuilder(
                listenable: downloadService,
                builder: (context, _) {
                  final tasks = downloadService.tasks;

                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无下载任务',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _DownloadTaskItem(
                        task: task,
                        downloadService: downloadService,
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(),

            // 底部操作栏
            ListenableBuilder(
              listenable: downloadService,
              builder: (context, _) {
                final hasCompleted = downloadService.tasks.any((t) =>
                    t.status == DownloadStatus.success ||
                    t.status == DownloadStatus.failed ||
                    t.status == DownloadStatus.canceled);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasCompleted)
                      TextButton.icon(
                        onPressed: () {
                          downloadService.clearCompleted();
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('清除已完成'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 下载任务列表项
class _DownloadTaskItem extends StatelessWidget {
  final DownloadTask task;
  final DownloadService downloadService;

  const _DownloadTaskItem({
    required this.task,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件名和状态
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildActions(context),
            ],
          ),

          // 进度条
          if (task.status == DownloadStatus.running) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.formattedSize,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (task.status) {
      case DownloadStatus.pending:
        icon = Icons.schedule;
        color = Colors.grey;
        break;
      case DownloadStatus.running:
        icon = Icons.downloading;
        color = Colors.blue;
        break;
      case DownloadStatus.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case DownloadStatus.canceled:
        icon = Icons.cancel;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.pending:
        return '等待中...';
      case DownloadStatus.running:
        return '下载中...';
      case DownloadStatus.success:
        return '已完成 - ${task.savePath ?? ''}';
      case DownloadStatus.failed:
        return '失败: ${task.error ?? '未知错误'}';
      case DownloadStatus.canceled:
        return '已取消';
    }
  }

  Color _getStatusColor() {
    switch (task.status) {
      case DownloadStatus.pending:
        return Colors.grey;
      case DownloadStatus.running:
        return Colors.blue;
      case DownloadStatus.success:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.canceled:
        return Colors.orange;
    }
  }

  Widget _buildActions(BuildContext context) {
    if (task.status == DownloadStatus.running) {
      return IconButton(
        icon: const Icon(Icons.close, size: 20),
        onPressed: () {
          downloadService.cancel(task.id);
        },
        tooltip: '取消',
      );
    }

    if (task.status == DownloadStatus.success) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            onPressed: () {
              downloadService.openFileLocation(task.id);
            },
            tooltip: '打开文件夹',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              downloadService.removeTask(task.id);
            },
            tooltip: '删除',
          ),
        ],
      );
    }

    if (task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.canceled) {
      return IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () {
          downloadService.removeTask(task.id);
        },
        tooltip: '删除',
      );
    }

    return const SizedBox.shrink();
  }
}
