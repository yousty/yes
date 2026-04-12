# frozen_string_literal: true

RSpec::Matchers.define :have_authorizer do
  match do |actual|
    actual&.authorizer_class&.< Yes::Core::Authorization::CommandAuthorizer
  end

  description do
    'have an authorizer'
  end
end

RSpec::Matchers.define :have_read_model_class do |read_model_class|
  match do |aggregate|
    aggregate.read_model_class == read_model_class
  end

  failure_message do |aggregate|
    "expected #{aggregate} to have read model class #{read_model_class}" \
      "\n  actual read model class is #{aggregate.read_model_class}"
  end
end

RSpec::Matchers.define :have_cerbos_authorizer do
  match do |aggregate|
    next false unless aggregate.authorizer_class&.< Yes::Core::Authorization::CommandCerbosAuthorizer

    next false if @read_model_class && aggregate.authorizer_options&.read_model_class != @read_model_class

    next false if @resource_name && aggregate.authorizer_options&.resource_name != @resource_name

    true
  end

  chain :with_read_model_class do |read_model_class|
    @read_model_class = read_model_class
  end

  chain :with_resource_name do |resource_name|
    @resource_name = resource_name
  end

  description do
    msg = 'have a Cerbos authorizer'
    msg += " with read model class #{@read_model_class}" if @read_model_class
    msg += " with resource name #{@resource_name}" if @resource_name
    msg
  end

  failure_message do |aggregate|
    msg = "expected #{aggregate} to have a Cerbos authorizer"
    msg += "\n  with read model class #{@read_model_class}" if @read_model_class
    msg += "\n  with resource name #{@resource_name}" if @resource_name
    msg += "\n    actual read model class is #{aggregate.authorizer_options&.read_model_class}" if @read_model_class
    msg += "\n    actual resource name is #{aggregate.authorizer_options&.resource_name}" if @resource_name
    msg
  end
end

RSpec::Matchers.define :have_parent do |parent_name|
  match do |aggregate|
    @parent = aggregate.parent_aggregates.with_indifferent_access[parent_name]

    return false unless @parent

    return true unless @context

    @parent[:context] == @context
  end

  chain :with_context do |context|
    @context = context
  end

  failure_message do |aggregate|
    msg = "expected #{aggregate} to have parent #{parent_name}"
    msg += "\n  with context #{@context}" if @context
    msg += "\n  actual context is #{@parent[:context].presence || aggregate.context}" if @parent && @context
    msg
  end
end
