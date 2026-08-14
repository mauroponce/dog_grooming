import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "submit", "status"]
  static values = { url: String }

  connect() {
    this.history = []
  }

  submit(event) {
    event.preventDefault()
    const question = this.inputTarget.value.trim()
    if (!question || this.loading) return

    this.appendMessage("user", question)
    this.inputTarget.value = ""
    this.setLoading(true)
    const loadingBubble = this.appendMessage("assistant", "Consultando los datos de tu negocio...")

    fetch(this.urlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({ question, history: this.history.slice(-8) })
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => ({}))
        if (!response.ok) throw new Error(payload.error || "No pude responder ahora.")
        return payload
      })
      .then((payload) => {
        const answer = payload.answer || "No encontré información suficiente para responder eso."
        this.replaceBubble(loadingBubble, answer)
        this.history.push({ role: "user", content: question })
        this.history.push({ role: "assistant", content: answer })
      })
      .catch((error) => {
        this.replaceBubble(loadingBubble, error.message || "No pude responder ahora.")
      })
      .finally(() => {
        this.setLoading(false)
      })
  }

  useSuggestion(event) {
    this.inputTarget.value = event.currentTarget.textContent.trim()
    this.inputTarget.focus()
  }

  appendMessage(role, content) {
    const message = document.createElement("div")
    message.className = role === "user" ? "admin-dashboard-message is-user" : "admin-dashboard-message"

    if (role !== "user") {
      const avatar = document.createElement("span")
      avatar.className = "admin-dashboard-chat-avatar admin-dashboard-chat-avatar-small"
      avatar.innerHTML = this.assistantIcon()
      message.appendChild(avatar)
    }

    const bubble = document.createElement("div")
    bubble.className = "admin-dashboard-bubble"
    if (role === "user") {
      bubble.textContent = content
    } else {
      bubble.innerHTML = this.formatText(content)
    }
    message.appendChild(bubble)
    this.messagesTarget.appendChild(message)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    return bubble
  }

  replaceBubble(bubble, content) {
    bubble.innerHTML = this.formatText(content)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  setLoading(value) {
    this.loading = value
    this.submitTarget.disabled = value
    this.inputTarget.disabled = value
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = value ? "Consultando datos..." : "Disponible · usa datos de tu negocio"
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  assistantIcon() {
    return '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3 9.8 8.8 4 11l5.8 2.2L12 19l2.2-5.8L20 11l-5.8-2.2L12 3Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>'
  }

  formatText(value) {
    const placeholders = []
    const reserve = (html) => {
      const token = `HTMARKDOWNPLACEHOLDER${placeholders.length}TOKEN`
      placeholders.push(html)
      return token
    }

    let text = String(value || "")
      .replace(/\[([^\]\n]+)\]\(\s*([^\)\s]+)\s*\)/g, (match, label, href) => {
        const safeHref = this.safeLinkHref(href)
        return safeHref ? reserve(this.linkHtml(safeHref, label)) : match
      })
      .replace(/`([^`]+)`/g, (_match, code) => {
        const safeHref = this.safeLinkHref(code)
        return safeHref ? reserve(this.linkHtml(safeHref, code)) : reserve(`<code>${this.escapeHtml(code)}</code>`)
      })

    text = this.autolinkPlainUrls(text, reserve)

    return this.escapeHtml(text)
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\n/g, "<br>")
      .replace(/HTMARKDOWNPLACEHOLDER(\d+)TOKEN/g, (_match, index) => placeholders[Number(index)] || "")
  }

  safeLinkHref(value) {
    const rawValue = String(value || "").trim()
    if (!rawValue || rawValue.startsWith("//")) return ""
    if (rawValue.startsWith("/")) return rawValue

    try {
      let normalizedValue = rawValue
      if (/^localhost(?::\d+)?(?:\/|$)/i.test(normalizedValue)) {
        normalizedValue = `http://${normalizedValue}`
      } else if (/^www\./i.test(normalizedValue)) {
        normalizedValue = `https://${normalizedValue}`
      } else if (/^(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/|$)/i.test(normalizedValue)) {
        normalizedValue = `https://${normalizedValue}`
      }

      const url = new URL(normalizedValue)
      return ["http:", "https:", "mailto:", "tel:"].includes(url.protocol) ? url.href : ""
    } catch (_) {
      return ""
    }
  }

  linkHtml(href, label) {
    const safeHref = this.safeLinkHref(href)
    if (!safeHref) return this.escapeHtml(label)

    return `<a href="${this.escapeHtml(safeHref)}" target="_blank" rel="noopener noreferrer">${this.escapeHtml(label)}</a>`
  }

  autolinkPlainUrls(value, reserve) {
    const urlPattern = /(^|[\s([<{])((?:https?:\/\/|www\.|localhost(?::\d+)?(?:\/|$)|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/|$))[^\s<]*)/gi

    return String(value || "").replace(urlPattern, (match, prefix, rawUrl) => {
      const trailing = rawUrl.match(/[)\].,!?:;]+$/)?.[0] || ""
      const cleanUrl = rawUrl.slice(0, rawUrl.length - trailing.length)
      const safeHref = this.safeLinkHref(cleanUrl)
      if (!safeHref) return match

      return `${prefix}${reserve(this.linkHtml(safeHref, cleanUrl))}${trailing}`
    })
  }

  escapeHtml(value) {
    const element = document.createElement("div")
    element.textContent = value || ""
    return element.innerHTML
  }
}
