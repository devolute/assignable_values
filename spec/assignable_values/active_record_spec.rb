require 'spec_helper'
require 'ostruct'

describe AssignableValues::ActiveRecord do

  def disposable_song_class(&block)
    @klass = Class.new(Song, &block)
    @klass.class_eval do
      def self.name
        'Song'
      end
    end
    @klass
  end

  describe '.assignable_values' do

    it 'should raise an error when not called with a block or :through option' do
      expect do
        disposable_song_class do
          assignable_values_for :genre
        end
      end.to raise_error(AssignableValues::NoValuesGiven)
    end

    context 'when validating scalar attributes' do

      context 'without options' do

        before :each do
          @klass = disposable_song_class do
            assignable_values_for :genre do
              %w[pop rock]
            end
          end
        end

        it 'should validate that the attribute is allowed' do
          @klass.new(:genre => 'pop').should be_valid
          @klass.new(:genre => 'disallowed value').should_not be_valid
        end

        it 'should not allow nil for the attribute value' do
          @klass.new(:genre => nil).should_not be_valid
        end

        it 'should allow a previously saved value even if that value is no longer allowed' do
          song = @klass.new(:genre => 'disallowed value')
          song.save!(:validate => false)
          song.should be_valid
        end

      end

      context 'if the :allow_blank option is set' do

        before :each do
          @klass = disposable_song_class do
            assignable_values_for :genre, :allow_blank => true do
              %w[pop rock]
            end
          end
        end

        it 'should allow nil for the attribute value' do
          @klass.new(:genre => nil).should be_valid
        end

        it 'should allow an empty string as value if the :allow_blank option is set' do
          @klass.new(:genre => '').should be_valid
        end

      end

      context 'when delegating using the :through option' do

        it 'should obtain allowed values from a method with the given name' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :through => :delegate
            def delegate
              OpenStruct.new(:assignable_song_genres => %w[pop rock])
            end
          end
          @klass.new(:genre => 'pop').should be_valid
          @klass.new(:genre => 'disallowed value').should_not be_valid
        end

        it 'should skip the validation if that method returns nil' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :through => :delegate
            def delegate
              nil
            end
          end
          @klass.new(:genre => 'pop').should be_valid
        end

      end

      context 'with :default option' do

        it 'should allow to set a default' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :default => 'pop' do
              %w[pop rock]
            end
          end
          @klass.new.genre.should == 'pop'
        end

        it 'should allow to set a default through a lambda' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :default => lambda { 'pop' } do
              %w[pop rock]
            end
          end
          @klass.new.genre.should == 'pop'
        end

        it 'should evaluate a lambda default in the context of the record instance' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :default => lambda { default_genre } do
              %w[pop rock]
            end
            def default_genre
              'pop'
            end
          end
          @klass.new.genre.should == 'pop'
        end

      end

    end

    context 'when validating belongs_to associations' do

      it 'should validate that the association is allowed' do
        allowed_association = Artist.create!
        disallowed_association = Artist.create!
        @klass = disposable_song_class do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        @klass.new(:artist => allowed_association).should be_valid
        @klass.new(:artist => disallowed_association).should_not be_valid
      end

      it 'should allow a nil association if the :allow_blank option is set' do
        @klass = disposable_song_class do
          assignable_values_for :artist do
            []
          end
        end
        record = @klass.new
        record.artist.should be_nil
        record.should be_valid
      end

      it 'should allow a previously saved association even if that association is no longer allowed' do
        allowed_association = Artist.create!
        disallowed_associtaion = Artist.create!
        @klass = disposable_song_class
        record = @klass.create!(:artist => disallowed_associtaion)
        @klass.class_eval do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        @klass.new(:artist => disallowed_association).should be_valid
      end

      it 'should not check a cached value against the list of assignable associations' do
        allowed_association = Artist.create!
        disallowed_association = Artist.create!
        @klass = disposable_song_class do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        record = @klass.create!(:artist => allowed_association)
        record.artist_id = disallowed_association.id
        record.should_not be_valid
      end

      context 'when delegating using the :through option' do

        it 'should obtain allowed values from a method with the given name'

        it 'should skip the validation if that method returns nil'
      end

    end

    context 'when generating methods to list assignable values' do

      it 'should generate an instance method returning a list of assignable values' do
        @klass = disposable_song_class do
          assignable_values_for :genre do
            %w[pop rock]
          end
        end
        @klass.new.assignable_genres.should == %w[pop rock]
      end

      it "should define a method #human on strings in that list, which return up the value's' translation" do
        @klass = disposable_song_class do
          assignable_values_for :genre do
            %w[pop rock]
          end
        end
        @klass.new.assignable_genres.collect(&:human).should == ['Pop music', 'Rock music']
      end

      it 'should use String#humanize as a default translation' do
        @klass = disposable_song_class do
          assignable_values_for :genre do
            %w[electronic]
          end
        end
        @klass.new.assignable_genres.collect(&:human).should == ['Electronic']
      end

      it 'should not define a method #human on values that are not strings' do
        @klass = disposable_song_class do
          assignable_values_for :year do
            [1999, 2000, 2001]
          end
        end
        years = @klass.new.assignable_years
        years.should == [1999, 2000, 2001]
        years.first.should_not respond_to(:human)
      end

      it 'should call #to_a on the list of assignable values, allowing ranges and scopes to be passed as allowed value descriptors' do
        @klass = disposable_song_class do
          assignable_values_for :year do
            1999..2001
          end
        end
        @klass.new.assignable_years.should == [1999, 2000, 2001]
      end

      it 'should evaluate the value block in the context of the record instance' do
        @klass = disposable_song_class do
          assignable_values_for :genre do
            genres
          end
          def genres
            %w[pop rock]
          end
        end
        @klass.new.assignable_genres.should == %w[pop rock]
      end

      context 'with :through option' do

        it 'should retrieve assignable values from the given method' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :through => :delegate
            def delegate
              @delegate ||= 'delegate'
            end
          end
          record = @klass.new
          record.delegate.should_receive(:assignable_song_genres).and_return %w[pop rock]
          record.assignable_genres.should == %w[pop rock]
        end

        it "should pass the record to the given method if the delegate's query method takes an argument" do
          delegate = Object.new
          def delegate.assignable_song_genres(record)
            record_received(record)
             %w[pop rock]
          end
          @klass = disposable_song_class do
            assignable_values_for :genre, :through => :delegate
            define_method :delegate do
              delegate
            end
          end
          record = @klass.new
          delegate.should_receive(:record_received).with(record)
          record.assignable_genres.should ==  %w[pop rock]
        end

        it 'should raise an error if the given method returns nil' do
          @klass = disposable_song_class do
            assignable_values_for :genre, :through => :delegate
            def delegate
              nil
            end
          end
          expect { @klass.new.assignable_genres }.to raise_error(AssignableValues::DelegateUnavailable)
        end

      end

    end

  end

  describe '.authorize_values_for' do

    it 'should be a shortcut for .assignable_values_for :attribute, :through => :power' do
      @klass = disposable_song_class
      @klass.should_receive(:assignable_values_for).with(:attribute, :option => 'option', :through => :power)
      @klass.class_eval do
        authorize_values_for :attribute, :option => 'option'
      end
    end

    it 'should generate a getter and setter for a @power field' do
      @klass = disposable_song_class do
        authorize_values_for :attribute
      end
      song = @klass.new
      song.should respond_to(:power)
      song.should respond_to(:power=)
    end

  end

end