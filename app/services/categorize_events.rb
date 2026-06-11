# Assigns each uncategorized event one of Event::CATEGORIES via the Claude
# API. Events the model leaves out (or a failed call) simply stay nil and are
# retried on the next run; the UI shows them as "Andere" in the meantime.
class CategorizeEvents
  MODEL = :"claude-opus-4-8"
  BATCH_SIZE = 100

  CATEGORIES_SCHEMA = {
    type: "object",
    properties: {
      categories: {
        type: "array",
        items: {
          type: "object",
          properties: {
            id: { type: "integer", description: "The event's id, exactly as given" },
            category: { type: "string", enum: Event::CATEGORIES }
          },
          required: %w[id category],
          additionalProperties: false
        }
      }
    },
    required: %w[categories],
    additionalProperties: false
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You categorize events for an Innsbruck events website. You receive a JSON list of
    events (id, name, organization, location, description) and assign exactly one
    category to every event:

    - Theater: plays, opera, performance, improv shows
    - Konzerte: live music of any genre, including festivals and symphony concerts
    - Party: club nights, DJ sets, raves
    - Kultur: exhibitions, film screenings, readings, talks, markets, community gatherings
    - Workshop: participatory sessions where attendees learn or practice something
      (classes, jams with instruction, open workshops)
    - Politik: demonstrations, political talks and debates, activism events
    - Andere: everything that fits none of the above

    The venue (organization) is a hint, not the answer — a club can host a workshop,
    a theater can host a concert. Judge by the event itself.
  PROMPT

  def self.call(events = Event.where(category: nil))
    events.each_slice(BATCH_SIZE) { |batch| categorize(batch) }
  end

  def self.categorize(events)
    message = anthropic.messages.create(
      model: MODEL,
      max_tokens: 16000,
      thinking: { type: "adaptive" },
      system_: SYSTEM_PROMPT,
      messages: [ { role: "user", content: events_json(events) } ],
      output_config: { format: { type: "json_schema", schema: CATEGORIES_SCHEMA } }
    )

    json = message.content.find { |block| block.type == :text }&.text
    raise "Claude returned no text content (stop_reason: #{message.stop_reason})" if json.nil?

    events_by_id = events.index_by(&:id)
    JSON.parse(json).fetch("categories").each do |row|
      # update_column: the category itself is constrained by the schema enum,
      # and unrelated validation problems on old rows must not block it.
      events_by_id[row["id"]]&.update_column(:category, row["category"])
    end
  end

  def self.events_json(events)
    events.map do |event|
      {
        id: event.id,
        name: event.name,
        organization: event.organization,
        location: event.location,
        description: event.description
      }
    end.to_json
  end

  def self.anthropic
    @anthropic ||= Anthropic::Client.new
  end

  private_class_method :categorize, :events_json, :anthropic
end
