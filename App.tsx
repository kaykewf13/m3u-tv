import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { LogBox } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { XtreamProvider } from './src/context/XtreamContext';
import { MenuProvider } from './src/context/MenuContext';
import { AppNavigator } from './src/navigation/AppNavigator';
import { PhoneNavigator } from './src/navigation/PhoneNavigator';
import { useShouldUseSidebar } from './src/hooks/useDeviceType';

LogBox.ignoreLogs(['Persistent storage is not supported on tvOS']);

export default function App() {
  const useSidebar = useShouldUseSidebar();

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <XtreamProvider>
          <MenuProvider>
            <StatusBar style="light" />
            {useSidebar ? <AppNavigator /> : <PhoneNavigator />}
          </MenuProvider>
        </XtreamProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
