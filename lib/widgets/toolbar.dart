import 'package:flutter/material.dart';

/// 功能工具栏组件
class Toolbar extends StatelessWidget {
  final VoidCallback? onReset;      // 重置网址
  final VoidCallback? onPrint;      // 打印
  final VoidCallback? onScreenshot; // 截图
  final VoidCallback? onExportPdf;  // 导出PDF
  final VoidCallback? onExportMd;   // 导出Markdown
  final bool isWebsiteLoaded;       // 是否已加载网站

  const Toolbar({
    super.key,
    this.onReset,
    this.onPrint,
    this.onScreenshot,
    this.onExportPdf,
    this.onExportMd,
    this.isWebsiteLoaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          
          // 重置按钮
          _ToolbarButton(
            icon: Icons.home_outlined,
            label: '重置网址',
            onPressed: onReset,
            color: Colors.blue,
          ),
          
          const SizedBox(width: 4),
          
          // 打印按钮
          _ToolbarButton(
            icon: Icons.print_outlined,
            label: '打印',
            onPressed: isWebsiteLoaded ? onPrint : null,
            color: Colors.green,
          ),
          
          const SizedBox(width: 4),
          
          // 截图按钮
          _ToolbarButton(
            icon: Icons.screenshot_outlined,
            label: '截图',
            onPressed: isWebsiteLoaded ? onScreenshot : null,
            color: Colors.orange,
          ),
          
          const SizedBox(width: 4),
          
          // 导出PDF按钮
          _ToolbarButton(
            icon: Icons.picture_as_pdf_outlined,
            label: '导出PDF',
            onPressed: isWebsiteLoaded ? onExportPdf : null,
            color: Colors.red,
          ),
          
          const SizedBox(width: 4),
          
          // 导出Markdown按钮
          _ToolbarButton(
            icon: Icons.article_outlined,
            label: '导出MD',
            onPressed: isWebsiteLoaded ? onExportMd : null,
            color: Colors.purple,
          ),
          
          const Spacer(),
          
          // 提示文字
          if (isWebsiteLoaded)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '工具栏',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color = Colors.blue,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;
    
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered && isEnabled
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: isEnabled
                      ? widget.color
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _isHovered && isEnabled
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isEnabled
                        ? (_isHovered ? widget.color : Colors.grey.shade700)
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
