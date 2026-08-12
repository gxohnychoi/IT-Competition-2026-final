import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/realtime_measurement_service.dart';
import '../widgets/common_widgets.dart';

/// 하드웨어팀 ESP32가 Realtime Database에 쏘는 원시값을 그대로 보여주는 화면.
/// 발표 데모에서 "실제로 하드웨어→클라우드→앱까지 연결됐다"를 눈으로
/// 보여주기 좋음. 필드명이 바뀌어도 안 깨지도록 Map을 그대로 렌더링.
class DeviceLiveScreen extends StatefulWidget {
  const DeviceLiveScreen({super.key});

  @override
  State<DeviceLiveScreen> createState() => _DeviceLiveScreenState();
}

class _DeviceLiveScreenState extends State<DeviceLiveScreen> {
  String? _selectedUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('기기 실시간 확인')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RFID 태그 목록', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '아직 필드명이 확정되지 않은 테스트 단계라, 하드웨어가 보내는 값을 그대로 보여줘요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<String>>(
                stream: RealtimeMeasurementService.instance.streamKnownUids(),
                builder: (context, snapshot) {
                  final uids = snapshot.data ?? [];
                  if (uids.isEmpty) {
                    return Text('아직 측정 데이터가 없어요.', style: Theme.of(context).textTheme.bodySmall);
                  }
                  _selectedUid ??= uids.first;
                  return Wrap(
                    spacing: 8,
                    children: [
                      for (final uid in uids)
                        ChoiceChip(
                          label: Text(uid),
                          selected: _selectedUid == uid,
                          onSelected: (_) => setState(() => _selectedUid = uid),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (_selectedUid != null) ...[
                Text('측정 기록 (최신순)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
                    stream: RealtimeMeasurementService.instance.streamMeasurements(_selectedUid!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final entries = snapshot.data!;
                      if (entries.isEmpty) {
                        return Text('이 태그의 측정 기록이 없어요.', style: Theme.of(context).textTheme.bodySmall);
                      }
                      return ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final fields = entries[i].value;
                          return SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (i == 0)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGreenBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('최신',
                                        style: TextStyle(fontSize: 10, color: AppColors.darkGreen)),
                                  ),
                                for (final key in fields.keys)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Text(key,
                                              style: const TextStyle(
                                                  fontSize: 12, color: AppColors.textSecondary)),
                                        ),
                                        Expanded(
                                          child: Text('${fields[key]}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
