require "yaml"

module Triggers
  class PresetLoader
    PRESET_PATH = Rails.root.join("config", "triggers", "v1", "presets.yml")

    Result = Struct.new(:created, :updated, :skipped, keyword_init: true) do
      def to_h
        { created: created, updated: updated, skipped: skipped }
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(preset_path: PRESET_PATH, logger: Rails.logger, force: false)
      @preset_path = Pathname(preset_path)
      @logger = logger
      @force = force
    end

    def call
      return Result.new(created: 0, updated: 0, skipped: 0) unless @preset_path.exist?

      payload = load_yaml
      result = Result.new(created: 0, updated: 0, skipped: 0)

      Trigger.transaction do
        payload.each do |raw_entry|
          entry = normalize_entry(raw_entry)
          trigger = Trigger.find_or_initialize_by(key: entry.fetch(:key))

          if should_update?(trigger, entry)
            trigger.assign_attributes(entry.except(:key))
            trigger.save!

            if trigger.previous_changes.key?("id")
              result.created += 1
            else
              result.updated += 1
            end
          else
            result.skipped += 1
          end
        end
      end

      @logger.info("[Triggers::PresetLoader] sync completed: #{result.to_h}")
      result
    rescue Psych::SyntaxError => e
      raise ArgumentError, "Invalid triggers preset YAML: #{e.message}"
    end

    private

    def load_yaml
      YAML.load_file(@preset_path) || []
    end

    def normalize_entry(raw_entry)
      entry = raw_entry.deep_symbolize_keys

      {
        key: entry.fetch(:key),
        label: entry.fetch(:label),
        category: entry.fetch(:category),
        is_active: entry.fetch(:is_active, true),
        version: entry.fetch(:version),
        rule: normalize_rule(entry[:rule])
      }
    end

    def normalize_rule(rule)
      return {} if rule.blank?

      case rule
      when Hash
        rule.deep_stringify_keys
      else
        raise ArgumentError, "Trigger rule must be a hash. Given: #{rule.class}"
      end
    end

    def should_update?(trigger, entry)
      return true if @force || trigger.new_record?

      trigger_attrs = {
        label: trigger.label,
        category: trigger.category,
        is_active: trigger.is_active,
        version: trigger.version,
        rule: (trigger.rule || {}).deep_stringify_keys
      }

      entry_attrs = entry.except(:key)
      entry_attrs[:rule] = entry_attrs[:rule].deep_stringify_keys

      trigger_attrs != entry_attrs
    end
  end
end
