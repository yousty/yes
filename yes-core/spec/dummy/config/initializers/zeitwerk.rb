# frozen_string_literal: true

module ReadModels
end

Rails.autoloaders.main.push_dir(
  Rails.root.join('app/read_models'),
  namespace: ReadModels
)

Rails.autoloaders.each do |loader|
  loader.collapse('app/contexts')
end
