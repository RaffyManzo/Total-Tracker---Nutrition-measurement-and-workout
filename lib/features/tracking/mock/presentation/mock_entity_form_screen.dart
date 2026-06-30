import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';

enum MockFormKind {
  day,
  meal,
  recipe,
  scale,
  tape,
  routine,
  plan,
  session,
}

class MockEntityFormScreen extends StatefulWidget {
  const MockEntityFormScreen({
    required this.kind,
    super.key,
  });

  final MockFormKind kind;

  @override
  State<MockEntityFormScreen> createState() => _MockEntityFormScreenState();
}

class _MockEntityFormScreenState extends State<MockEntityFormScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final List<TextEditingController> controllers =
      List<TextEditingController>.generate(
    18,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (final TextEditingController controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get title {
    switch (widget.kind) {
      case MockFormKind.day:
        return 'Nuova giornata';
      case MockFormKind.meal:
        return 'Nuovo pasto';
      case MockFormKind.recipe:
        return 'Nuova ricetta';
      case MockFormKind.scale:
        return 'Nuova misurazione bilancia';
      case MockFormKind.tape:
        return 'Nuova misurazione metro';
      case MockFormKind.routine:
        return 'Nuova routine';
      case MockFormKind.plan:
        return 'Nuova scheda';
      case MockFormKind.session:
        return 'Nuova sessione';
    }
  }

  String get returnRoute {
    switch (widget.kind) {
      case MockFormKind.day:
        return '/diary';
      case MockFormKind.meal:
        return '/meals';
      case MockFormKind.recipe:
        return '/recipes';
      case MockFormKind.scale:
      case MockFormKind.tape:
        return '/measurements';
      case MockFormKind.routine:
        return '/routines';
      case MockFormKind.plan:
        return '/plans';
      case MockFormKind.session:
        return '/sessions';
    }
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salvataggio simulato: ObjectBox non è ancora collegato'),
      ),
    );
    context.go(returnRoute);
  }

  Widget field(
    int index,
    String label, {
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controllers[index],
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: isRequired
            ? (String? value) => value == null || value.trim().isEmpty
                ? 'Campo obbligatorio'
                : null
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  List<Widget> buildFields() {
    switch (widget.kind) {
      case MockFormKind.day:
        return <Widget>[
          const TtSectionHeader(title: 'Giornata'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Data *', isRequired: true),
          field(1, 'Target kcal', keyboardType: TextInputType.number),
          field(2, 'Calorie assunte', keyboardType: TextInputType.number),
          field(3, 'Calorie attive', keyboardType: TextInputType.number),
          field(4, 'Peso (kg)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          field(5, 'Passi', keyboardType: TextInputType.number),
          field(6, 'Acqua (litri)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          field(7, 'Sonno (ore)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          field(8, 'Note', maxLines: 4),
        ];
      case MockFormKind.meal:
        return <Widget>[
          const TtSectionHeader(title: 'Informazioni pasto'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Titolo *', isRequired: true),
          field(1, 'Data *', isRequired: true),
          field(2, 'Tipo pasto'),
          field(3, 'Modalità: standard/libero/stimato'),
          field(4, 'Elementi e quantità', maxLines: 5),
          field(5, 'Calorie', keyboardType: TextInputType.number),
          field(6, 'Proteine (g)', keyboardType: TextInputType.number),
          field(7, 'Carboidrati (g)', keyboardType: TextInputType.number),
          field(8, 'Grassi (g)', keyboardType: TextInputType.number),
          field(9, 'Note', maxLines: 3),
        ];
      case MockFormKind.recipe:
        return <Widget>[
          const TtSectionHeader(title: 'Ricetta'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Titolo *', isRequired: true),
          field(1, 'Sottotitolo'),
          field(2, 'Porzioni', keyboardType: TextInputType.number),
          field(3, 'Tempo preparazione (min)',
              keyboardType: TextInputType.number),
          field(4, 'Tempo cottura (min)', keyboardType: TextInputType.number),
          field(5, 'Difficoltà'),
          field(6, 'Ingredienti, uno per riga', maxLines: 6),
          field(7, 'Passaggi, uno per riga', maxLines: 6),
          field(8, 'Resa finale (g)', keyboardType: TextInputType.number),
          field(9, 'Kcal per porzione', keyboardType: TextInputType.number),
          field(10, 'Tag'),
        ];
      case MockFormKind.scale:
        return <Widget>[
          const TtSectionHeader(title: 'Bilancia'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Data e ora *', isRequired: true),
          field(1, 'Peso (kg) *',
              isRequired: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          field(2, 'Massa grassa (%)', keyboardType: TextInputType.number),
          field(3, 'Massa muscolare (kg)', keyboardType: TextInputType.number),
          field(4, 'Acqua corporea (%)', keyboardType: TextInputType.number),
          field(5, 'Massa ossea (kg)', keyboardType: TextInputType.number),
          field(6, 'Grasso viscerale', keyboardType: TextInputType.number),
          field(7, 'Metabolismo basale', keyboardType: TextInputType.number),
          field(8, 'BMI', keyboardType: TextInputType.number),
          field(9, 'Età metabolica', keyboardType: TextInputType.number),
          field(10, 'Dispositivo'),
          field(11, 'Affidabilità'),
          field(12, 'Note', maxLines: 3),
        ];
      case MockFormKind.tape:
        return <Widget>[
          const TtSectionHeader(title: 'Metro'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Data e ora *', isRequired: true),
          field(1, 'Vita (cm)', keyboardType: TextInputType.number),
          field(2, 'Fianchi (cm)', keyboardType: TextInputType.number),
          field(3, 'Torace (cm)', keyboardType: TextInputType.number),
          field(4, 'Braccio destro (cm)', keyboardType: TextInputType.number),
          field(5, 'Braccio sinistro (cm)', keyboardType: TextInputType.number),
          field(6, 'Coscia destra (cm)', keyboardType: TextInputType.number),
          field(7, 'Coscia sinistra (cm)', keyboardType: TextInputType.number),
          field(8, 'Affidabilità'),
          field(9, 'Note', maxLines: 3),
        ];
      case MockFormKind.routine:
        return <Widget>[
          const TtSectionHeader(title: 'Routine'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Nome *', isRequired: true),
          field(1, 'Obiettivo'),
          field(2, 'Descrizione'),
          field(3, 'Esercizi, uno per riga', maxLines: 6),
          field(4, 'Serie e ripetizioni', maxLines: 4),
          field(5, 'Recuperi', maxLines: 3),
          field(6, 'Note', maxLines: 4),
        ];
      case MockFormKind.plan:
        return <Widget>[
          const TtSectionHeader(title: 'Scheda allenamento'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Nome *', isRequired: true),
          field(1, 'Livello'),
          field(2, 'Stato'),
          field(3, 'Giorni della scheda', maxLines: 5),
          field(4, 'Esercizi per giorno', maxLines: 8),
          field(5, 'Serie, ripetizioni e recuperi', maxLines: 6),
          field(6, 'Note', maxLines: 4),
        ];
      case MockFormKind.session:
        return <Widget>[
          const TtSectionHeader(title: 'Sessione'),
          const SizedBox(height: AppSpacing.md),
          field(0, 'Titolo *', isRequired: true),
          field(1, 'Data *', isRequired: true),
          field(2, 'Routine o scheda di origine'),
          field(3, 'Stato'),
          field(4, 'Durata (min)', keyboardType: TextInputType.number),
          field(5, 'Battito medio', keyboardType: TextInputType.number),
          field(6, 'Calorie attive stimate',
              keyboardType: TextInputType.number),
          field(7, 'Esercizi e risultati', maxLines: 8),
          field(8, 'Serie completate', maxLines: 6),
          field(9, 'Note', maxLines: 4),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
            ...buildFields(),
            const SizedBox(height: AppSpacing.md),
            TtPrimaryButton(
              label: 'Salva mock',
              icon: Icons.check_rounded,
              onPressed: save,
            ),
          ],
        ),
      ),
    );
  }
}
