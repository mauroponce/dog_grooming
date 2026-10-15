const { test } = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const path = require("node:path")

const source = fs.readFileSync(path.resolve(__dirname, "../../app/javascript/controllers/whatsapp_signup_controller.js"), "utf8")
  .replace(/^import .*\n/, "")
  .replace("export default class", "class WhatsAppSignup") + "\nWhatsAppSignup"

function harness({ protocol = "https:", sdk = true } = {}) {
  const timers = new Map()
  let nextTimer = 0
  const calls = { submissions: 0, listeners: new Set() }
  const facebook = {
    init: (options) => { calls.init = options },
    login: (callback, options) => { calls.callback = callback; calls.options = options }
  }
  const window = { location: { protocol }, FB: sdk ? facebook : undefined,
    addEventListener: (_, callback) => calls.listeners.add(callback),
    removeEventListener: (_, callback) => calls.listeners.delete(callback) }
  const document = { createElement: () => ({ remove() {} }), head: { appendChild: (script) => { calls.script = script } } }
  const Klass = vm.runInNewContext(source, { Controller: class {}, window, document,
    setTimeout: (callback) => { timers.set(++nextTimer, callback); return nextTimer },
    clearTimeout: (id) => timers.delete(id) })
  const signup = new Klass()
  signup.element = { isConnected: true }
  signup.appIdValue = "test-app"
  signup.configIdValue = "test-config"
  signup.versionValue = "v25.0"
  for (const name of ["code", "event", "waba", "phone"]) signup[`${name}Target`] = { value: "" }
  signup.statusTarget = { textContent: "" }
  signup.buttonTarget = { disabled: false }
  signup.formTarget = { requestSubmit: () => calls.submissions++ }
  signup.initialize()
  signup.ready = sdk
  function message(event, data = {}, origin = "https://www.facebook.com") {
    signup.receive({ origin, data: JSON.stringify({ type: "WA_EMBEDDED_SIGNUP", event, data }) })
  }
  return { signup, calls, window, facebook, timers, message }
}

test("launches the official SDK with the v4 configuration and only the Coexistence selector", async () => {
  const { signup, calls } = harness()
  await signup.connect()
  signup.login()
  assert.equal(calls.init.version, "v25.0")
  assert.equal(calls.options.config_id, "test-config")
  assert.equal(calls.options.response_type, "code")
  assert.equal(calls.options.override_default_response_type, true)
  assert.deepEqual(Object.keys(calls.options.extras), ["featureType"])
  assert.equal(calls.options.extras.featureType, "whatsapp_business_app_onboarding")
})

test("submits once when completion precedes the code, even without asset IDs", () => {
  const { signup, calls, message } = harness()
  signup.login()
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING")
  assert.equal(calls.submissions, 0)
  calls.callback({ authResponse: { code: "test-code" } })
  calls.callback({ authResponse: { code: "test-code" } })
  assert.equal(calls.submissions, 1)
  assert.equal(signup.phoneTarget.value, "")
})

test("submits once when the code precedes completion", () => {
  const { signup, calls, message, timers } = harness()
  signup.login()
  calls.callback({ authResponse: { code: "test-code" } })
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING", { waba_id: "456" })
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING", { waba_id: "456" })
  assert.equal(calls.submissions, 1)
  assert.equal(signup.wabaTarget.value, "456")
  assert.equal(timers.size, 0)
})

test("rejects untrusted origins and events outside an active signup", () => {
  const { signup, calls, message } = harness()
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING")
  assert.equal(signup.eventTarget.value, "")
  signup.login()
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING", {}, "https://evilfacebook.com")
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING", {}, "https://www.facebook.com.evil.example")
  calls.callback({ authResponse: { code: "test-code" } })
  assert.equal(calls.submissions, 0)
  assert.equal(signup.eventTarget.value, "")
  signup.disconnect()
})

test("stops conventional Cloud API completion without submitting credentials", () => {
  for (const finish of ["FINISH", "FINISH_ONLY_WABA", "FINISH_OBO_MIGRATION"]) {
    const { signup, calls, message } = harness()
    signup.login()
    message(finish)
    calls.callback({ authResponse: { code: "test-code" } })
    assert.equal(calls.submissions, 0)
    assert.equal(signup.codeTarget.value, "")
    assert.match(signup.statusTarget.textContent, /no se admite migración/)
  }
})

test("handles cancellation and errors without rendering raw provider data", () => {
  for (const event of ["CANCEL", "ERROR"]) {
    const { signup, calls, message } = harness()
    signup.login()
    message(event, { error_message: "private-data" })
    assert.equal(calls.submissions, 0)
    assert.equal(signup.buttonTarget.disabled, false)
    assert.doesNotMatch(signup.statusTarget.textContent, /private-data/)
  }
})

test("expires an incomplete code instead of submitting a non-Coexistence flow", () => {
  const { signup, calls, timers } = harness()
  signup.login()
  calls.callback({ authResponse: { code: "test-code" } })
  Array.from(timers.values())[0]()
  assert.equal(calls.submissions, 0)
  assert.equal(signup.codeTarget.value, "")
  assert.equal(signup.buttonTarget.disabled, false)
})

test("requires HTTPS and cleans up listeners on disconnect", async () => {
  const { signup, calls } = harness({ protocol: "http:" })
  await signup.connect()
  signup.login()
  assert.equal(calls.callback, undefined)
  assert.match(signup.statusTarget.textContent, /HTTPS/)
  signup.disconnect()
  assert.equal(calls.listeners.size, 0)
})

test("recovers from SDK loading errors without logging credentials", async () => {
  const { signup, calls, window } = harness({ sdk: false })
  const loading = signup.connect()
  assert.equal(calls.script.src, "https://connect.facebook.net/es_LA/sdk.js")
  calls.script.onerror()
  await loading
  assert.equal(signup.buttonTarget.disabled, false)
  assert.equal(window.citapetFacebookSDK, null)
})

test("ignores callbacks from an abandoned earlier attempt", () => {
  const { signup, calls, message } = harness()
  signup.login()
  const earlier = calls.callback
  message("CANCEL")
  signup.login()
  message("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING")
  earlier({ authResponse: { code: "stale-code" } })
  assert.equal(calls.submissions, 0)
  calls.callback({ authResponse: { code: "new-code" } })
  assert.equal(calls.submissions, 1)
  assert.equal(signup.codeTarget.value, "new-code")
})
