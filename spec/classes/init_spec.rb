require 'spec_helper'

describe 'pabawi' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        
        it 'includes proxy class when proxy_manage is true' do
          is_expected.to contain_class('pabawi::proxy::nginx')
        end
        
        it 'includes install class when install_manage is true' do
          is_expected.to contain_class('pabawi::install::npm')
        end
      end

      context 'when proxy_manage is false' do
        let(:params) do
          {
            proxy_manage: false,
          }
        end

        it { is_expected.to compile.with_all_deps }
        
        it 'does not include proxy class' do
          is_expected.not_to contain_class('pabawi::proxy::nginx')
        end
      end

      context 'with custom proxy_class' do
        let(:params) do
          {
            proxy_class: 'pabawi::proxy::custom',
          }
        end

        it 'includes the custom proxy class' do
          is_expected.to contain_class('pabawi::proxy::custom')
        end
      end

      context 'with invalid proxy_class' do
        let(:params) do
          {
            proxy_class: 'Invalid-Class-Name',
          }
        end

        it 'fails with validation error' do
          is_expected.to compile.and_raise_error(/Invalid proxy_class/)
        end
      end

      context 'when install_manage is false' do
        let(:params) do
          {
            install_manage: false,
          }
        end

        it { is_expected.to compile.with_all_deps }
        
        it 'does not include install class' do
          is_expected.not_to contain_class('pabawi::install::npm')
        end
      end

      context 'with both proxy and install managed' do
        it 'ensures proxy comes before install' do
          is_expected.to contain_class('pabawi::proxy::nginx').that_comes_before('Class[pabawi::install::npm]')
        end
      end

      context 'with bolt in integrations' do
        let(:params) do
          {
            integrations: ['bolt'],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes bolt integration class' do
          is_expected.to contain_class('pabawi::integrations::bolt')
        end
      end

      context 'with puppetdb in integrations' do
        let(:params) do
          {
            integrations: ['puppetdb'],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes puppetdb integration class' do
          is_expected.to contain_class('pabawi::integrations::puppetdb')
        end
      end

      context 'with custom integrations array' do
        let(:params) do
          {
            integrations: ['terraform'],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes listed integration classes' do
          is_expected.to contain_class('pabawi::integrations::terraform')
        end

        it 'does not include unlisted integration classes' do
          is_expected.not_to contain_class('pabawi::integrations::ansible')
        end

        it 'creates notify resource for each integration' do
          is_expected.to contain_notify('pabawi_integration_terraform').with(
            'message' => 'Enabling integration: pabawi::integrations::terraform',
            'loglevel' => 'notice',
          )
        end
      end

      context 'with multiple integrations' do
        let(:params) do
          {
            integrations: ['bolt', 'puppetdb', 'custom'],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'includes all listed integration classes' do
          is_expected.to contain_class('pabawi::integrations::bolt')
          is_expected.to contain_class('pabawi::integrations::puppetdb')
          is_expected.to contain_class('pabawi::integrations::custom')
        end
      end

      context 'with invalid integration type' do
        let(:params) do
          {
            integrations: [123],
          }
        end

        it 'fails with validation error' do
          is_expected.to compile.and_raise_error(/expects an Array\[String/)
        end
      end
    end
  end
end
