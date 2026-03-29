// @ts-check
const { withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

/**
 * Expo config plugin that ensures the MPVKit CocoaPods source is available
 * for iOS/tvOS builds. The MPVKit pod is resolved from the spec repo at
 * https://github.com/nicoboss/MPVKit.
 *
 * On Android, the JitPack Maven repo is added via expo-build-properties
 * (extraMavenRepos in app.json), so no additional config is needed here.
 */
const withMpvPlayer = (config) => {
  // iOS: ensure MPVKit pod source is available in the Podfile
  config = withDangerousMod(config, [
    'ios',
    (mod) => {
      const podfilePath = path.join(mod.modRequest.platformProjectRoot, 'Podfile');

      if (!fs.existsSync(podfilePath)) {
        return mod;
      }

      let podfile = fs.readFileSync(podfilePath, 'utf8');

      // Add the MPVKit podspec repo source if not already present
      const mpvKitSource = "source 'https://github.com/nicoboss/MPVKit.git'";
      if (!podfile.includes(mpvKitSource)) {
        // Insert before the first `platform` or `target` line
        const insertBefore = podfile.match(/^(platform|target)\s/m);
        if (insertBefore && insertBefore.index !== undefined) {
          podfile =
            podfile.slice(0, insertBefore.index) +
            mpvKitSource +
            '\n' +
            podfile.slice(insertBefore.index);
        } else {
          // Fallback: prepend
          podfile = mpvKitSource + '\n' + podfile;
        }

        fs.writeFileSync(podfilePath, podfile, 'utf8');
      }

      return mod;
    },
  ]);

  return config;
};

module.exports = withMpvPlayer;
