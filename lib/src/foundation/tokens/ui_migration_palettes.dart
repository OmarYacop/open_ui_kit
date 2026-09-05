import 'dart:ui';

/// An immutable 50–950 color scale for migrations from utility-first UI kits.
///
/// These are raw color references, not theme roles. Application UI should map
/// them into [UiColorTokens] instead of reading a shade directly in widgets.
class UiColorScale {
  const UiColorScale({
    required this.s50,
    required this.s100,
    required this.s200,
    required this.s300,
    required this.s400,
    required this.s500,
    required this.s600,
    required this.s700,
    required this.s800,
    required this.s900,
    required this.s950,
  });

  final Color s50;
  final Color s100;
  final Color s200;
  final Color s300;
  final Color s400;
  final Color s500;
  final Color s600;
  final Color s700;
  final Color s800;
  final Color s900;
  final Color s950;

  Color operator [](int shade) => switch (shade) {
    50 => s50,
    100 => s100,
    200 => s200,
    300 => s300,
    400 => s400,
    500 => s500,
    600 => s600,
    700 => s700,
    800 => s800,
    900 => s900,
    950 => s950,
    _ => throw ArgumentError.value(shade, 'shade', 'Use 50–950'),
  };
}

/// Tailwind-compatible sRGB scales, also familiar to shadcn developers.
///
/// Tailwind v4 publishes colors in OKLCH. These sRGB values intentionally use
/// the widely adopted hex-compatible scale so Flutter developers can migrate
/// existing color references without adding a color-space conversion layer.
abstract final class UiTailwindPalette {
  static const slate = UiColorScale(
    s50: Color(0xFFF8FAFC),
    s100: Color(0xFFF1F5F9),
    s200: Color(0xFFE2E8F0),
    s300: Color(0xFFCBD5E1),
    s400: Color(0xFF94A3B8),
    s500: Color(0xFF64748B),
    s600: Color(0xFF475569),
    s700: Color(0xFF334155),
    s800: Color(0xFF1E293B),
    s900: Color(0xFF0F172A),
    s950: Color(0xFF020617),
  );
  static const gray = UiColorScale(
    s50: Color(0xFFF9FAFB),
    s100: Color(0xFFF3F4F6),
    s200: Color(0xFFE5E7EB),
    s300: Color(0xFFD1D5DB),
    s400: Color(0xFF9CA3AF),
    s500: Color(0xFF6B7280),
    s600: Color(0xFF4B5563),
    s700: Color(0xFF374151),
    s800: Color(0xFF1F2937),
    s900: Color(0xFF111827),
    s950: Color(0xFF030712),
  );
  static const zinc = UiColorScale(
    s50: Color(0xFFFAFAFA),
    s100: Color(0xFFF4F4F5),
    s200: Color(0xFFE4E4E7),
    s300: Color(0xFFD4D4D8),
    s400: Color(0xFFA1A1AA),
    s500: Color(0xFF71717A),
    s600: Color(0xFF52525B),
    s700: Color(0xFF3F3F46),
    s800: Color(0xFF27272A),
    s900: Color(0xFF18181B),
    s950: Color(0xFF09090B),
  );
  static const neutral = UiColorScale(
    s50: Color(0xFFFAFAFA),
    s100: Color(0xFFF5F5F5),
    s200: Color(0xFFE5E5E5),
    s300: Color(0xFFD4D4D4),
    s400: Color(0xFFA3A3A3),
    s500: Color(0xFF737373),
    s600: Color(0xFF525252),
    s700: Color(0xFF404040),
    s800: Color(0xFF262626),
    s900: Color(0xFF171717),
    s950: Color(0xFF0A0A0A),
  );
  static const stone = UiColorScale(
    s50: Color(0xFFFAFAF9),
    s100: Color(0xFFF5F5F4),
    s200: Color(0xFFE7E5E4),
    s300: Color(0xFFD6D3D1),
    s400: Color(0xFFA8A29E),
    s500: Color(0xFF78716C),
    s600: Color(0xFF57534E),
    s700: Color(0xFF44403C),
    s800: Color(0xFF292524),
    s900: Color(0xFF1C1917),
    s950: Color(0xFF0C0A09),
  );
  static const red = UiColorScale(
    s50: Color(0xFFFEF2F2),
    s100: Color(0xFFFEE2E2),
    s200: Color(0xFFFECACA),
    s300: Color(0xFFFCA5A5),
    s400: Color(0xFFF87171),
    s500: Color(0xFFEF4444),
    s600: Color(0xFFDC2626),
    s700: Color(0xFFB91C1C),
    s800: Color(0xFF991B1B),
    s900: Color(0xFF7F1D1D),
    s950: Color(0xFF450A0A),
  );
  static const orange = UiColorScale(
    s50: Color(0xFFFFF7ED),
    s100: Color(0xFFFFEDD5),
    s200: Color(0xFFFED7AA),
    s300: Color(0xFFFDBA74),
    s400: Color(0xFFFB923C),
    s500: Color(0xFFF97316),
    s600: Color(0xFFEA580C),
    s700: Color(0xFFC2410C),
    s800: Color(0xFF9A3412),
    s900: Color(0xFF7C2D12),
    s950: Color(0xFF431407),
  );
  static const amber = UiColorScale(
    s50: Color(0xFFFFFBEB),
    s100: Color(0xFFFEF3C7),
    s200: Color(0xFFFDE68A),
    s300: Color(0xFFFCD34D),
    s400: Color(0xFFFBBF24),
    s500: Color(0xFFF59E0B),
    s600: Color(0xFFD97706),
    s700: Color(0xFFB45309),
    s800: Color(0xFF92400E),
    s900: Color(0xFF78350F),
    s950: Color(0xFF451A03),
  );
  static const yellow = UiColorScale(
    s50: Color(0xFFFEFCE8),
    s100: Color(0xFFFEF9C3),
    s200: Color(0xFFFEF08A),
    s300: Color(0xFFFDE047),
    s400: Color(0xFFFACC15),
    s500: Color(0xFFEAB308),
    s600: Color(0xFFCA8A04),
    s700: Color(0xFFA16207),
    s800: Color(0xFF854D0E),
    s900: Color(0xFF713F12),
    s950: Color(0xFF422006),
  );
  static const lime = UiColorScale(
    s50: Color(0xFFF7FEE7),
    s100: Color(0xFFECFCCB),
    s200: Color(0xFFD9F99D),
    s300: Color(0xFFBEF264),
    s400: Color(0xFFA3E635),
    s500: Color(0xFF84CC16),
    s600: Color(0xFF65A30D),
    s700: Color(0xFF4D7C0F),
    s800: Color(0xFF3F6212),
    s900: Color(0xFF365314),
    s950: Color(0xFF1A2E05),
  );
  static const green = UiColorScale(
    s50: Color(0xFFF0FDF4),
    s100: Color(0xFFDCFCE7),
    s200: Color(0xFFBBF7D0),
    s300: Color(0xFF86EFAC),
    s400: Color(0xFF4ADE80),
    s500: Color(0xFF22C55E),
    s600: Color(0xFF16A34A),
    s700: Color(0xFF15803D),
    s800: Color(0xFF166534),
    s900: Color(0xFF14532D),
    s950: Color(0xFF052E16),
  );
  static const emerald = UiColorScale(
    s50: Color(0xFFECFDF5),
    s100: Color(0xFFD1FAE5),
    s200: Color(0xFFA7F3D0),
    s300: Color(0xFF6EE7B7),
    s400: Color(0xFF34D399),
    s500: Color(0xFF10B981),
    s600: Color(0xFF059669),
    s700: Color(0xFF047857),
    s800: Color(0xFF065F46),
    s900: Color(0xFF064E3B),
    s950: Color(0xFF022C22),
  );
  static const teal = UiColorScale(
    s50: Color(0xFFF0FDFA),
    s100: Color(0xFFCCFBF1),
    s200: Color(0xFF99F6E4),
    s300: Color(0xFF5EEAD4),
    s400: Color(0xFF2DD4BF),
    s500: Color(0xFF14B8A6),
    s600: Color(0xFF0D9488),
    s700: Color(0xFF0F766E),
    s800: Color(0xFF115E59),
    s900: Color(0xFF134E4A),
    s950: Color(0xFF042F2E),
  );
  static const cyan = UiColorScale(
    s50: Color(0xFFECFEFF),
    s100: Color(0xFFCFFAFE),
    s200: Color(0xFFA5F3FC),
    s300: Color(0xFF67E8F9),
    s400: Color(0xFF22D3EE),
    s500: Color(0xFF06B6D4),
    s600: Color(0xFF0891B2),
    s700: Color(0xFF0E7490),
    s800: Color(0xFF155E75),
    s900: Color(0xFF164E63),
    s950: Color(0xFF083344),
  );
  static const sky = UiColorScale(
    s50: Color(0xFFF0F9FF),
    s100: Color(0xFFE0F2FE),
    s200: Color(0xFFBAE6FD),
    s300: Color(0xFF7DD3FC),
    s400: Color(0xFF38BDF8),
    s500: Color(0xFF0EA5E9),
    s600: Color(0xFF0284C7),
    s700: Color(0xFF0369A1),
    s800: Color(0xFF075985),
    s900: Color(0xFF0C4A6E),
    s950: Color(0xFF082F49),
  );
  static const blue = UiColorScale(
    s50: Color(0xFFEFF6FF),
    s100: Color(0xFFDBEAFE),
    s200: Color(0xFFBFDBFE),
    s300: Color(0xFF93C5FD),
    s400: Color(0xFF60A5FA),
    s500: Color(0xFF3B82F6),
    s600: Color(0xFF2563EB),
    s700: Color(0xFF1D4ED8),
    s800: Color(0xFF1E40AF),
    s900: Color(0xFF1E3A8A),
    s950: Color(0xFF172554),
  );
  static const indigo = UiColorScale(
    s50: Color(0xFFEEF2FF),
    s100: Color(0xFFE0E7FF),
    s200: Color(0xFFC7D2FE),
    s300: Color(0xFFA5B4FC),
    s400: Color(0xFF818CF8),
    s500: Color(0xFF6366F1),
    s600: Color(0xFF4F46E5),
    s700: Color(0xFF4338CA),
    s800: Color(0xFF3730A3),
    s900: Color(0xFF312E81),
    s950: Color(0xFF1E1B4B),
  );
  static const violet = UiColorScale(
    s50: Color(0xFFF5F3FF),
    s100: Color(0xFFEDE9FE),
    s200: Color(0xFFDDD6FE),
    s300: Color(0xFFC4B5FD),
    s400: Color(0xFFA78BFA),
    s500: Color(0xFF8B5CF6),
    s600: Color(0xFF7C3AED),
    s700: Color(0xFF6D28D9),
    s800: Color(0xFF5B21B6),
    s900: Color(0xFF4C1D95),
    s950: Color(0xFF2E1065),
  );
  static const purple = UiColorScale(
    s50: Color(0xFFFAF5FF),
    s100: Color(0xFFF3E8FF),
    s200: Color(0xFFE9D5FF),
    s300: Color(0xFFD8B4FE),
    s400: Color(0xFFC084FC),
    s500: Color(0xFFA855F7),
    s600: Color(0xFF9333EA),
    s700: Color(0xFF7E22CE),
    s800: Color(0xFF6B21A8),
    s900: Color(0xFF581C87),
    s950: Color(0xFF3B0764),
  );
  static const fuchsia = UiColorScale(
    s50: Color(0xFFFDF4FF),
    s100: Color(0xFFFAE8FF),
    s200: Color(0xFFF5D0FE),
    s300: Color(0xFFF0ABFC),
    s400: Color(0xFFE879F9),
    s500: Color(0xFFD946EF),
    s600: Color(0xFFC026D3),
    s700: Color(0xFFA21CAF),
    s800: Color(0xFF86198F),
    s900: Color(0xFF701A75),
    s950: Color(0xFF4A044E),
  );
  static const pink = UiColorScale(
    s50: Color(0xFFFDF2F8),
    s100: Color(0xFFFCE7F3),
    s200: Color(0xFFFBCFE8),
    s300: Color(0xFFF9A8D4),
    s400: Color(0xFFF472B6),
    s500: Color(0xFFEC4899),
    s600: Color(0xFFDB2777),
    s700: Color(0xFFBE185D),
    s800: Color(0xFF9D174D),
    s900: Color(0xFF831843),
    s950: Color(0xFF500724),
  );
  static const rose = UiColorScale(
    s50: Color(0xFFFFF1F2),
    s100: Color(0xFFFFE4E6),
    s200: Color(0xFFFECDD3),
    s300: Color(0xFFFDA4AF),
    s400: Color(0xFFFB7185),
    s500: Color(0xFFF43F5E),
    s600: Color(0xFFE11D48),
    s700: Color(0xFFBE123C),
    s800: Color(0xFF9F1239),
    s900: Color(0xFF881337),
    s950: Color(0xFF4C0519),
  );
}

/// Familiar shadcn neutral choices and default accent scale.
abstract final class UiShadcnPalette {
  static const slate = UiTailwindPalette.slate;
  static const gray = UiTailwindPalette.gray;
  static const zinc = UiTailwindPalette.zinc;
  static const neutral = UiTailwindPalette.neutral;
  static const stone = UiTailwindPalette.stone;
  static const accent = UiTailwindPalette.zinc;
}

/// Radix Colors light-theme solid anchors (step 9).
///
/// Radix's complete 12-step scales encode usage as well as hue. Use this
/// compatibility namespace when migrating a solid accent, then map it to an
/// Open UI semantic token. It intentionally does not pretend step numbers are
/// interchangeable with Tailwind shade numbers.
abstract final class UiRadixPalette {
  static const gray = Color(0xFF8D8D8D);
  static const mauve = Color(0xFF8E8C99);
  static const slate = Color(0xFF8B8D98);
  static const sage = Color(0xFF868E8B);
  static const olive = Color(0xFF898E87);
  static const sand = Color(0xFF8D8D86);
  static const gold = Color(0xFF978365);
  static const bronze = Color(0xFFA18072);
  static const brown = Color(0xFFAD7F58);
  static const yellow = Color(0xFFFFE629);
  static const amber = Color(0xFFFFC53D);
  static const orange = Color(0xFFF76B15);
  static const tomato = Color(0xFFE54D2E);
  static const red = Color(0xFFE5484D);
  static const ruby = Color(0xFFE54666);
  static const crimson = Color(0xFFE93D82);
  static const pink = Color(0xFFD6409F);
  static const plum = Color(0xFFAB4ABA);
  static const purple = Color(0xFF8E4EC6);
  static const violet = Color(0xFF6E56CF);
  static const iris = Color(0xFF5B5BD6);
  static const indigo = Color(0xFF3E63DD);
  static const blue = Color(0xFF0090FF);
  static const cyan = Color(0xFF00A2C7);
  static const teal = Color(0xFF12A594);
  static const jade = Color(0xFF29A383);
  static const green = Color(0xFF30A46C);
  static const grass = Color(0xFF46A758);
  static const lime = Color(0xFF99D52A);
  static const mint = Color(0xFF86EAD4);
  static const sky = Color(0xFF7CE2FE);
}

/// Bootstrap 5.3 base color anchors for direct migration.
abstract final class UiBootstrapPalette {
  static const blue = Color(0xFF0D6EFD);
  static const indigo = Color(0xFF6610F2);
  static const purple = Color(0xFF6F42C1);
  static const pink = Color(0xFFD63384);
  static const red = Color(0xFFDC3545);
  static const orange = Color(0xFFFD7E14);
  static const yellow = Color(0xFFFFC107);
  static const green = Color(0xFF198754);
  static const teal = Color(0xFF20C997);
  static const cyan = Color(0xFF0DCAF0);
}

/// Ant Design v5 primary anchors for its twelve base palettes.
abstract final class UiAntPalette {
  static const red = Color(0xFFF5222D);
  static const volcano = Color(0xFFFA541C);
  static const orange = Color(0xFFFA8C16);
  static const gold = Color(0xFFFAAD14);
  static const yellow = Color(0xFFFADB14);
  static const lime = Color(0xFFA0D911);
  static const green = Color(0xFF52C41A);
  static const cyan = Color(0xFF13C2C2);
  static const blue = Color(0xFF1677FF);
  static const geekBlue = Color(0xFF2F54EB);
  static const purple = Color(0xFF722ED1);
  static const magenta = Color(0xFFEB2F96);
}
