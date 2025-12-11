import 'package:flutter/material.dart';

/// 异常错误页 - 网络错误、加载失败等
class ErrorPage extends StatelessWidget {
  final String errorMessage;
  final String? url;
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;

  const ErrorPage({
    super.key,
    required this.errorMessage,
    this.url,
    this.onRetry,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade50,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 错误图标
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 80,
                  color: Colors.red,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 标题
              const Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 错误信息
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // URL信息（如果有）
              if (url != null && url!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Row(
                    children: [
                      Icon(Icons.link, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          url!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              
              // 常见问题和解决方案
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '请尝试以下解决方案',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSolutionItem(
                      Icons.wifi,
                      '检查网络连接',
                      '确保您的设备已连接到互联网',
                    ),
                    const SizedBox(height: 12),
                    _buildSolutionItem(
                      Icons.vpn_key,
                      '检查网址',
                      '确认输入的网址正确且支持HTTPS',
                    ),
                    const SizedBox(height: 12),
                    _buildSolutionItem(
                      Icons.security,
                      '防火墙设置',
                      '检查防火墙是否阻止了访问',
                    ),
                    const SizedBox(height: 12),
                    _buildSolutionItem(
                      Icons.schedule,
                      '稍后重试',
                      '网站服务器可能暂时不可用',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onGoBack != null)
                    OutlinedButton.icon(
                      onPressed: onGoBack,
                      icon: const Icon(Icons.home),
                      label: const Text('返回首页'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  
                  if (onGoBack != null && onRetry != null)
                    const SizedBox(width: 16),
                  
                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新加载'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // 技术信息（可折叠）
              _buildTechnicalInfo(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSolutionItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTechnicalInfo() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '技术详情',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            '错误信息: $errorMessage\n'
            '${url != null ? 'URL: $url\n' : ''}'
            '时间: ${DateTime.now().toString()}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
