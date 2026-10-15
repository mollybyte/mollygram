/// The plugins settings screen (design/Plugins.dc.html) and loading of the
/// built-in plugins. Spec: docs/plugins.md.
library;

export 'src/builtin.dart';
export 'src/colors.dart' show PluginsColors, PluginsTheme;
export 'src/controller.dart';
export 'src/mock.dart';
export 'src/screen.dart';
export 'src/strings.dart'
    show AccessIcon, AccessRow, PluginTexts, PluginsStrings;
export 'src/widgets.dart'
    show
        AccessIconView,
        MgSelect,
        MgTextField,
        PluginIcon,
        monoFallback,
        monoFamily;
