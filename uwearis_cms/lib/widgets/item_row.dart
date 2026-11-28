import 'package:flutter/material.dart';

import '../models/admin_models.dart';

/// A featured item in a story's content: photo, name, and whether it's
/// buyable, with an action at the end.
class ItemRow extends StatelessWidget {
  final AdminItem? item;
  final int? missingId;
  final Widget trailing;

  const ItemRow({
    super.key,
    required this.item,
    required this.missingId,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final url = item?.imageUrl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox.square(
        dimension: 48,
        child: url == null
            ? const Icon(Icons.checkroom_outlined)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
      title: Text(
        item?.displayName ??
            (missingId != null ? '單品 #$missingId（找不到）' : '尚未選擇單品'),
      ),
      subtitle: item == null
          ? null
          : Text(
              [
                if (item.brand != null) item.brand!,
                item.product == null
                    ? '沒有連結商品（只介紹）'
                    : '可購買：${item.product!.name}',
              ].join(' · '),
            ),
      trailing: trailing,
    );
  }
}
