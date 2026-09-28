/// Public, unauthenticated URLs the shipped app is allowed to open.
///
/// Everything linked from inside the app has to resolve for a stranger who just
/// downloaded an installer. The `jasonzacmusic/nsm-flow` repository is private,
/// so linking to it (or to its releases page) shows a GitHub 404 to everyone
/// outside the organisation. These constants are the only URLs the UI opens.
export const NSM_FLOW_PRODUCT_URL =
  "https://labs.nathanielschool.com/products/nsm-flow";

/// Where installers actually live. Stable across releases: the hub always
/// points at the newest published asset.
export const NSM_FLOW_DOWNLOADS_URL =
  "https://jasonzacmusic.github.io/labs-downloads/";

/// Nathaniel School of Music's public site.
export const NSM_SITE_URL = "https://nathanielschool.com";
