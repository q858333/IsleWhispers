const tabPaths = ['/pages/home/index', '/pages/library/index', '/pages/settings/index'];

export function selectedTabIndex(path) {
  const index = tabPaths.indexOf(path);
  return index < 0 ? 0 : index;
}

export function tabBarAppearance(path) {
  return selectedTabIndex(path) === 0 ? 'dark' : 'light';
}

export { tabPaths };
