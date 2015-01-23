RSpec.describe Psy::Configuration::Builder do
  let(:instance) do
    described_class.new(parent) do
      set(:app_name, 'MyApp')
      set(:vars, hello: 'world', foo: 'bar')

      environment :development do
        set(:app_name, 'YourApp')
        set(:handler, :dev)
      end
    end
  end
  let(:result) { instance.build(env) }

  let(:name)   { :default }
  let(:parent) { nil }

  describe '#logger' do
    subject { instance.logger(logger) }

    let(:env) { :development }

    let(:stubs) do
      { log: true, debug: true, info: true, warn: true, error: true, fatal: true }
    end

    context 'when responds to #log, #debug, #info, #warn, #error, #fatal' do
      let(:logger) { instance_double('Logger', stubs) }

      it { expect { subject }.to_not raise_error }
    end

    %i(log debug info warn error fatal).each do |severity|
      context "when does not responds to ##{severity}" do
        let(:logger) do
          double(stubs.tap { |s| s.delete(severity) })
        end

        it 'raises error' do
          expect { subject }.to raise_error(Psy::Configuration::InvalidLoggerError, "logger must respond to ##{severity}")
        end
      end
    end

    context 'when not given' do
      it 'initializes stdlib Logger' do
        expect(result.logger).to be_instance_of(Logger)
      end

      it 'writes to $stdout' do
        expect { result.logger.log(0, 'foo') }.to output(/foo/).to_stdout
      end
    end

    context 'when defined in environment' do
      let(:logger) { instance_double('Logger', stubs) }
      let(:another_logger) { instance_double('Logger', stubs) }

      before(:each) do
        logger_instance = another_logger

        instance.environment :development do
          logger(logger_instance)
        end
      end

      context 'and not defined anywhere else' do
        it { expect(result.logger).to equal(another_logger) }
      end

      context 'and in default env' do
        before(:each) { subject }

        it { expect(result.logger).to equal(another_logger) }
      end

      context 'but another environment given' do
        let(:env) { :production }

        context 'when defined in default env' do
          before(:each) { subject }

          it 'overwrites default logger' do
            expect(result.logger).to equal(logger)
          end
        end

        context 'when not defined in default env' do
          it 'ignores another env' do
            expect(result.logger).to be_instance_of(Logger)
          end
        end
      end
    end

    context 'when defined in parent' do
      let(:logger) { instance_double('Logger', stubs) }
      let(:parent_logger) { instance_double('Logger', stubs) }
      let(:parent) do
        logger_instance = parent_logger

        described_class.new do
          logger(logger_instance)
        end.build(env)
      end

      context 'when defined in children' do
        before(:each) { subject }

        it 'should be overwritten' do
          expect(result.logger).to equal(logger)
        end
      end

      context 'when not defined in children' do
        it 'uses parent logger' do
          expect(result.logger).to equal(parent_logger)
        end
      end

      context 'when defined in children environment' do
        before(:each) do
          subject
          logger_instance = env_logger
          instance.environment :development do
            logger(logger_instance)
          end
        end

        let(:env_logger) { instance_double('Logger', stubs) }

        it 'uses environment logger' do
          expect(result.logger).to eql(env_logger)
        end
      end
    end
  end

  describe '#params_hash' do

  end

  describe '#set' do
    context 'simple value' do
      context 'when environment not specified' do
        let(:env) { :production }

        it 'returns value' do
          expect(result.app_name).to eql('MyApp')
        end
      end

      context 'when environment specified' do
        let(:env) { :development }

        context 'key was set in default env' do
          subject { result.app_name }

          it 'overwrites value' do
            expect(subject).to eql('YourApp')
          end
        end

        context 'key was not set in default env' do
          subject { result.handler }

          it 'returns value' do
            expect(subject).to equal(:dev)
          end
        end
      end

      context 'when parent given' do
        let(:parent) do
          described_class.new do
            set(:app_name, 'BaseApp')
            set(:app_path, '/app')
          end.build(env)
        end
        let(:env) { :production }

        context 'not defined in child' do
          subject { result.app_path }

          it 'returns parents value' do
            expect(subject).to eql('/app')
          end
        end

        context 'defined in child' do
          subject { result.app_name }

          it 'returns child value' do
            expect(subject).to eql('MyApp')
          end
        end

        context 'defined in child and environment' do
          subject { result.app_name }

          let(:env) { :development }

          it 'returns environment value' do
            expect(subject).to eql('YourApp')
          end
        end
      end
    end

    context 'hash value' do
      subject { result.vars }
      let(:env) { :development }

      it { expect(subject).to eql(hello: 'world', foo: 'bar') }
    end

    context 'block'
  end
end
