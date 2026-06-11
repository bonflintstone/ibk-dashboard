# Reviews a webform submission with the Claude API: legitimate events are
# approved (published) and categorized in one call; spam stays unapproved
# and only ever goes live if an admin approves it manually in /admin.
class ReviewEvent
  MODEL = :"claude-opus-4-8"

  REVIEW_SCHEMA = {
    type: "object",
    properties: {
      spam: { type: "boolean", description: "true if the submission is spam or abuse rather than a real public event" },
      category: { type: "string", enum: Event::CATEGORIES }
    },
    required: %w[spam category],
    additionalProperties: false
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You review event submissions from the public webform of an Innsbruck events website.

    Decide whether the submission is a real, public event in or around Innsbruck —
    or spam/abuse: advertising without an actual event, SEO link placement, nonsense
    or test submissions, offensive content, or things with no plausible connection
    to Innsbruck. A real event that is merely sloppily entered is NOT spam; when in
    doubt about a plausible event, treat it as legitimate.

    Also assign exactly one category:
    - Theater: plays, opera, performance, improv shows
    - Konzerte: live music of any genre, including festivals and symphony concerts
    - Party: club nights, DJ sets, raves
    - Kultur: exhibitions, film screenings, readings, talks, markets, community gatherings
    - Workshop: participatory sessions where attendees learn or practice something
    - Politik: demonstrations, political talks and debates, activism events
    - Andere: everything that fits none of the above
  PROMPT

  def self.call(event)
    message = anthropic.messages.create(
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system_: SYSTEM_PROMPT,
      messages: [ { role: "user", content: event_json(event) } ],
      output_config: { format: { type: "json_schema", schema: REVIEW_SCHEMA } }
    )

    json = message.content.find { |block| block.type == :text }&.text
    raise "Claude returned no text content (stop_reason: #{message.stop_reason})" if json.nil?

    result = JSON.parse(json)
    if result["spam"]
      event.update!(category: result["category"])
    else
      event.update!(category: result["category"], approved_at: Time.current)
    end
  end

  def self.event_json(event)
    event.slice(:name, :link, :location, :datetime, :description).to_json
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  private_class_method :event_json, :anthropic
end
