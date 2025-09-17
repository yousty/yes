# frozen_string_literal: true

RSpec.describe 'AbTestsController routing' do
  describe 'GET' do
    context 'when read model is registered' do
      it '/queries/apprenticeships => yes/read/api/queries#call' do
        expect(get('/queries/apprenticeships')).to(
          route_to(controller: 'yes/read/api/queries', action: 'call', 'model' => 'apprenticeships')
        )
      end
    end

    context 'when read model is not registered' do
      it '/queries/lehrstellen => 404' do
        expect(get('/queries/lehrstellen')).not_to be_routable
      end
    end
  end

  describe 'POST' do
    context 'when read model is registered' do
      it '/queries/apprenticeships => yes/read/api/queries#advanced' do
        expect(post('/queries/apprenticeships')).to(
          route_to(controller: 'yes/read/api/queries', action: 'advanced', 'model' => 'apprenticeships')
        )
      end
    end

    context 'when read model is not registered' do
      it '/queries/lehrstellen => 404' do
        expect(post('/queries/lehrstellen')).not_to be_routable
      end
    end
  end
end

