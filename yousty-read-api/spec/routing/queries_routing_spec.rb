# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AbTestsController routing' do
  describe 'GET' do
    context 'when read model is registered' do
      it '/queries/apprenticeships => yousty/read/api/queries#call' do
        expect(get('/queries/apprenticeships')).to(
          route_to(controller: 'yousty/read/api/queries', action: 'call', 'model' => 'apprenticeships')
        )
      end
    end

    context 'when read model is not registered' do
      it '/queries/lehrstellen => 404' do
        expect(get('/queries/lehrstellen')).not_to be_routable
      end
    end
  end
end
