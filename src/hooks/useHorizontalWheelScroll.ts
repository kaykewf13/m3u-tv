import { useEffect, useRef } from 'react';
import { Platform, View } from 'react-native';

/**
 * On web, converts vertical mouse wheel events to horizontal scrolling
 * for the first scrollable child element inside the ref'd container.
 * Returns a ref to attach to the container View wrapping a horizontal ScrollView.
 * No-op on native platforms.
 */
export function useHorizontalWheelScroll() {
  const ref = useRef<View>(null);

  useEffect(() => {
    if (Platform.OS !== 'web') return;
    const el = ref.current as unknown as HTMLElement;
    if (!el?.addEventListener) return;

    const handler = (e: WheelEvent) => {
      if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;
      const divs = el.querySelectorAll('div');
      for (const div of Array.from(divs)) {
        if (div.scrollWidth > div.clientWidth) {
          e.preventDefault();
          div.scrollLeft += e.deltaY;
          return;
        }
      }
    };

    el.addEventListener('wheel', handler, { passive: false });
    return () => el.removeEventListener('wheel', handler);
  }, []);

  return ref;
}
