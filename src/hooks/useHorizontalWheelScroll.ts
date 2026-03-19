import { useEffect, useRef } from 'react';
import { Platform, View } from 'react-native';

/**
 * On web, converts vertical mouse wheel events to horizontal scrolling
 * for the first scrollable child element inside the ref'd container.
 * Also ensures the child has overflowX: 'auto' so the global scrollbar
 * CSS can kick in on hover.
 * Returns a ref to attach to the container View wrapping a horizontal ScrollView.
 * No-op on native platforms.
 */
export function useHorizontalWheelScroll() {
  const ref = useRef<View>(null);

  useEffect(() => {
    if (Platform.OS !== 'web') return;
    const el = ref.current as unknown as HTMLElement;
    if (!el?.addEventListener) return;

    let scrollableEl: HTMLElement | null = null;

    const findScrollable = (): HTMLElement | null => {
      if (scrollableEl) return scrollableEl;
      // RN Web sets overflow:hidden on ScrollViews, hiding the real scroll width.
      // Temporarily toggle overflow to measure, then set overflowX: auto on the match.
      const divs = el.querySelectorAll('div');
      for (const div of Array.from(divs)) {
        const orig = div.style.overflowX;
        div.style.overflowX = 'auto';
        if (div.scrollWidth > div.clientWidth) {
          scrollableEl = div;
          return div;
        }
        div.style.overflowX = orig;
      }
      return null;
    };

    const handler = (e: WheelEvent) => {
      if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;
      const scrollable = findScrollable();
      if (scrollable) {
        e.preventDefault();
        scrollable.scrollLeft += e.deltaY;
      }
    };

    // Find and enable horizontal scroll on the correct child
    const setup = () => {
      const scrollable = findScrollable();
      if (scrollable) {
        scrollable.style.overflowX = 'auto';
        scrollable.classList.add('m3u-scroll');
      }
    };
    setup();
    const timer = setTimeout(setup, 500);

    el.addEventListener('wheel', handler, { passive: false });
    return () => {
      clearTimeout(timer);
      el.removeEventListener('wheel', handler);
      scrollableEl = null;
    };
  }, []);

  return ref;
}
