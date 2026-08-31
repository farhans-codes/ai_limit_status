const hostName = "com.ailimitstatus.browser_bridge";
let nativePort;
let reconnectTimer;
let updateTimer;

function getCookies(details) {
  return new Promise((resolve) => {
    chrome.cookies.getAll(details, (cookies) => resolve(cookies || []));
  });
}

async function readSnapshot() {
  const [chatgptCookies, claudeCookies] = await Promise.all([
    getCookies({ url: "https://chatgpt.com/" }),
    getCookies({ domain: "claude.ai" }),
  ]);
  const hasChatGptSession = chatgptCookies.some(({ name }) => {
    const normalized = name.toLowerCase();
    return normalized.includes("session-token") ||
      normalized.includes("authjs") ||
      normalized.includes("next-auth") ||
      normalized === "_account";
  });
  const claudeSession = claudeCookies.find(
    ({ name, value }) => name === "sessionKey" && value.startsWith("sk-ant-"),
  );
  return {
    version: 1,
    chatgptCookieHeader: hasChatGptSession
      ? chatgptCookies.map(({ name, value }) => `${name}=${value}`).join("; ")
      : null,
    claudeSessionKey: claudeSession?.value || null,
  };
}

async function sendSnapshot() {
  if (!nativePort) return;
  try {
    nativePort.postMessage(await readSnapshot());
  } catch (_) {
    // The bridge reconnects when the installed native host becomes available.
  }
}

function connect() {
  clearTimeout(reconnectTimer);
  if (nativePort) return;
  try {
    nativePort = chrome.runtime.connectNative(hostName);
    nativePort.onDisconnect.addListener(() => {
      void chrome.runtime.lastError;
      nativePort = undefined;
      reconnectTimer = setTimeout(connect, 5000);
    });
    void sendSnapshot();
  } catch (_) {
    reconnectTimer = setTimeout(connect, 5000);
  }
}

chrome.cookies.onChanged.addListener(({ cookie }) => {
  const domain = cookie.domain.replace(/^\./, "");
  if (!domain.endsWith("chatgpt.com") && !domain.endsWith("claude.ai")) return;
  clearTimeout(updateTimer);
  updateTimer = setTimeout(() => void sendSnapshot(), 250);
});
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
connect();
