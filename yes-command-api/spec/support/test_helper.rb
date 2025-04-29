# frozen_string_literal: true

class TestHelper
  class << self
    def clean_up_config
      Yousty::Eventsourcing.instance_variable_set(:@config, nil)
    end
  end
end
