import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../domain/mock_exercise.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    this.initialExercise,
    super.key,
  });

  final MockExercise? initialExercise;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  static const List<String> availableMuscles = <String>[
    'Petto',
    'Dorso',
    'Spalle',
    'Bicipiti',
    'Tricipiti',
    'Quadricipiti',
    'Femorali',
    'Glutei',
    'Polpacci',
    'Core',
  ];

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController mediaController;
  late final TextEditingController restController;
  late final TextEditingController notesController;

  late String mode;
  late Set<String> primaryMuscles;
  late Set<String> secondaryMuscles;

  @override
  void initState() {
    super.initState();
    final MockExercise? exercise = widget.initialExercise;
    nameController = TextEditingController(text: exercise?.name ?? '');
    mediaController = TextEditingController(text: exercise?.media ?? '');
    restController = TextEditingController(
      text: exercise?.defaultRestSeconds.toString() ?? '90',
    );
    notesController = TextEditingController(text: exercise?.notes ?? '');
    mode = exercise?.mode ?? 'gym';
    primaryMuscles = <String>{...?exercise?.primaryMuscles};
    secondaryMuscles = <String>{...?exercise?.secondaryMuscles};
  }

  @override
  void dispose() {
    nameController.dispose();
    mediaController.dispose();
    restController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void togglePrimary(String muscle, bool selected) {
    setState(() {
      if (selected) {
        primaryMuscles.add(muscle);
        secondaryMuscles.remove(muscle);
      } else {
        primaryMuscles.remove(muscle);
      }
    });
  }

  void toggleSecondary(String muscle, bool selected) {
    setState(() {
      if (selected) {
        secondaryMuscles.add(muscle);
        primaryMuscles.remove(muscle);
      } else {
        secondaryMuscles.remove(muscle);
      }
    });
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (primaryMuscles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno un muscolo principale'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.initialExercise == null
              ? 'Esercizio salvato nella demo'
              : 'Esercizio aggiornato nella demo',
        ),
      ),
    );
    context.go('/exercises');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialExercise == null
              ? 'Nuovo esercizio'
              : 'Modifica esercizio',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            const TtSectionHeader(title: 'Informazioni generali'),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: nameController,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il nome';
                }
                return null;
              },
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: 'ModalitÃƒÂ '),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'gym',
                  child: Text('Palestra'),
                ),
                DropdownMenuItem(
                  value: 'activity',
                  child: Text('AttivitÃƒÂ '),
                ),
                DropdownMenuItem(
                  value: 'treadmill',
                  child: Text('Treadmill'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    mode = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: mediaController,
              decoration: const InputDecoration(
                labelText: 'Percorso o URL media',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: restController,
              keyboardType: TextInputType.number,
              validator: (String? value) {
                final int? parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Inserisci secondi validi';
                }
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Recupero predefinito (secondi)',
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(
              title: 'Muscoli principali',
              subtitle:
                  'Un muscolo selezionato come principale viene rimosso dai secondari.',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: availableMuscles.map((String muscle) {
                return FilterChip(
                  label: Text(muscle),
                  selected: primaryMuscles.contains(muscle),
                  onSelected: (bool selected) =>
                      togglePrimary(muscle, selected),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Muscoli secondari'),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: availableMuscles.map((String muscle) {
                return FilterChip(
                  label: Text(muscle),
                  selected: secondaryMuscles.contains(muscle),
                  onSelected: (bool selected) =>
                      toggleSecondary(muscle, selected),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note tecniche',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TtPrimaryButton(
              label: widget.initialExercise == null
                  ? 'Salva esercizio'
                  : 'Salva modifiche',
              icon: Icons.check_rounded,
              onPressed: save,
            ),
          ],
        ),
      ),
    );
  }
}
