require "uri"

class Tutorial < ApplicationRecord
  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  validates :title, presence: true, length: { maximum: 180 }
  validates :video_url, presence: true, length: { maximum: 2_048 }
  validate :video_url_uses_http

  def embed_url
    uri = URI.parse(video_url)
    video_id = uri.path.match(%r{\A/(?:share|embed)/([^/?#]+)})&.captures&.first

    return "https://www.loom.com/embed/#{video_id}" if uri.host.to_s.downcase.in?(%w[loom.com www.loom.com]) && video_id.present?

    video_url
  rescue URI::InvalidURIError
    video_url
  end

  private
    def video_url_uses_http
      uri = URI.parse(video_url.to_s)
      return if uri.is_a?(URI::HTTP) && uri.host.present?

      errors.add(:video_url, "debe ser un enlace http:// o https:// válido")
    rescue URI::InvalidURIError
      errors.add(:video_url, "debe ser un enlace http:// o https:// válido")
    end
end
