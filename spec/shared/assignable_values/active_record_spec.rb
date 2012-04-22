require 'spec_helper'
require 'ostruct'

describe AssignableValues::ActiveRecord do

  describe '.assignable_values' do

    it 'should raise an error when not called with a block or :through option' do
      expect do
        Song.disposable_copy do
          assignable_values_for :genre
        end
      end.to raise_error(AssignableValues::NoValuesGiven)
    end

    context 'when validating scalar attributes' do

      context 'without options' do

        before :each do
          @klass = Song.disposable_copy do
            assignable_values_for :genre do
              %w[pop rock]
            end
            assignable_values_for :active, :allow_blank => true do
              [true, false]
            end
          end
        end

        it 'should validate that the attribute is allowed' do
          @klass.new(:genre => 'pop').should be_valid
          @klass.new(:genre => 'disallowed value').should_not be_valid
        end

        it 'should use the same error message as validates_inclusion_of' do
          record = @klass.new(:genre => 'disallowed value')
          record.valid?
          errors = record.errors[:genre]
          error = errors.is_a?(Array) ? errors.first : errors # the return value sometimes was a string, sometimes an Array in Rails
          error.should == I18n.t('errors.messages.inclusion')
          error.should == 'is not included in the list'
        end

        it 'should not allow nil for the attribute value' do
          @klass.new(:genre => nil).should_not be_valid
        end

        it 'should allow a previously saved value even if that value is no longer allowed' do
          record = @klass.create!(:genre => 'pop')
          @klass.update_all(:genre => 'disallowed value') # update without validations for the sake of this test
          record.reload.should be_valid
        end

        context "for a string value" do
        
          it 'should generate a method returning the humanized value' do
            song = @klass.new(:genre => 'pop')
            song.humanized_genre.should == 'Pop music'
          end

          it 'should generate a method returning the humanized value, which is nil when the value is blank' do
            song = @klass.new
            song.genre = nil
            song.humanized_genre.should be_nil
            song.genre = ''
            song.humanized_genre.should be_nil
          end
        
        end

        it 'should generate a method to retrieve the humanization of any given value' do
          song = @klass.new(:genre => 'pop')
          song.humanized_genre('rock').should == 'Rock music'
        end

        context "for a boolean value" do
        
          it 'should generate a method returning the humanized value' do
            song = @klass.new(:active => true)
            song.humanized_active.should == 'Yes'
          end

          it 'should generate a method returning the humanized value, which is nil when the value is blank' do
            song = @klass.new
            song.active = nil
            song.humanized_active.should be_nil
            song.active = ''
            song.humanized_active.should be_nil
          end
          
          
        end
        
      end

      context 'if the :allow_blank option is set' do

        before :each do
          @klass = Song.disposable_copy do
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

    end

    context 'when validating belongs_to associations' do

      it 'should validate that the association is allowed' do
        allowed_association = Artist.create!
        disallowed_association = Artist.create!
        klass = Song.disposable_copy do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        klass.new(:artist => allowed_association).should be_valid
        klass.new(:artist => disallowed_association).should_not be_valid
      end

      it 'should allow a nil association if the :allow_blank option is set' do
        klass = Song.disposable_copy do
          assignable_values_for :artist, :allow_blank => true do
            []
          end
        end
        record = klass.new
        record.artist.should be_nil
        record.should be_valid
      end

      it 'should allow a previously saved association even if that association is no longer allowed' do
        allowed_association = Artist.create!
        disallowed_association = Artist.create!
        klass = Song.disposable_copy
        record = klass.create!(:artist => disallowed_association)
        klass.class_eval do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        record.should be_valid
      end

      it "should not load a previously saved association if the association's foreign key hasn't changed" do
        association = Artist.create!
        klass = Song.disposable_copy do
          assignable_values_for :artist do
            [association] # This example doesn't care about what's assignable. We're only interested in behavior up to the validation.
          end
        end
        record = klass.create!(:artist => association)
        Artist.should_not_receive(:find_by_id)
        record.valid?
      end

      it 'should not fail or allow nil if a previously saved association no longer exists in the database' do
        allowed_association = Artist.create!
        klass = Song.disposable_copy do
          assignable_values_for :artist do
            [allowed_association]
          end
        end
        record = klass.new
        record.stub :artist_id_was => -1
        record.should_not be_valid
      end

      it 'should uncache a stale association before validating' do
        klass = Song.disposable_copy do
          assignable_values_for :artist do
            [] # This example doesn't care about what's assignable. We're only interested in behavior up to the validation.
          end
        end
        association = Artist.create!
        record = klass.new
        record.stub(:artist => association, :artist_id => -1) # This is a stale association: The associated object's id doesn't match the foreign key. This can happen in Rails 2, not Rails 3.
        record.should_receive(:artist).ordered.and_return(association)
        record.should_receive(:artist).ordered.with(true).and_return(association)
        record.valid?
      end

      it 'should not uncache a fresh association before validating' do
        klass = Song.disposable_copy do
          assignable_values_for :artist do
            [] # This example doesn't care about what's assignable. We're only interested in behavior up to the validation.
          end
        end
        association = Artist.create!
        record = klass.new
        record.stub(:artist => association, :artist_id => association.id) # This is a fresh association: The associated object's id matches the foreign key.
        record.should_receive(:artist).with(no_args).and_return(association)
        record.valid?
      end

    end

    context 'when delegating using the :through option' do

      it 'should obtain allowed values from a method with the given name' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :through => :delegate
          def delegate
            OpenStruct.new(:assignable_song_genres => %w[pop rock])
          end
        end
        klass.new(:genre => 'pop').should be_valid
        klass.new(:genre => 'disallowed value').should_not be_valid
      end

      it 'should be able to delegate to a proc, which is evaluated in the context of the record instance' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :through => proc { delegate }
          def delegate
            OpenStruct.new(:assignable_song_genres => %w[pop rock])
          end
        end
        klass.new(:genre => 'pop').should be_valid
        klass.new(:genre => 'disallowed value').should_not be_valid
      end

      it 'should skip the validation if that method returns nil' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :through => :delegate
          def delegate
            nil
          end
        end
        klass.new(:genre => 'pop').should be_valid
      end

    end

    context 'with :default option' do

      it 'should allow to set a default' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'pop' do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'pop'
      end

      it 'should allow to set a default through a proc' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => proc { 'pop' } do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'pop'
      end

      it 'should evaluate a proc default in the context of the record instance' do
         klass = Song.disposable_copy do
          assignable_values_for :genre, :default => proc { default_genre } do
            %w[pop rock]
          end
          def default_genre
            'pop'
          end
        end
        klass.new.genre.should == 'pop'
      end

    end

    context 'with :secondary_default option' do

      it 'should set a secondary default value if the primary value is not assignable' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno', :secondary_default => 'rock' do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'rock'
      end

      it 'should not change the default value if the default value is assignable' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'pop', :secondary_default => 'rock' do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'pop'
      end

      it "should not change the primary default if the secondary default value isn't assignable either" do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno', :secondary_default => 'jazz' do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'techno'
      end

      it 'should raise an error if used without a :default option' do
        expect do
          Song.disposable_copy do
            assignable_values_for :genre, :secondary_default => 'pop' do
              %w[pop rock]
            end
          end
        end.to raise_error(AssignableValues::NoDefault)
      end

      it 'should allow to set a secondary default through a lambda' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno', :secondary_default => lambda { 'pop' } do
            %w[pop rock]
          end
        end
        klass.new.genre.should == 'pop'
      end

      it 'should evaluate a secondary lambda default in the context of the record instance' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno', :secondary_default => lambda { default_genre } do
            %w[pop rock]
          end
          def default_genre
            'pop'
          end
        end
        klass.new.genre.should == 'pop'
      end

      it "should not raise an error or change the primary default if assignable values are retrieved through a delegate, and the delegate is nil" do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno', :secondary_default => 'pop', :through => lambda { nil }
        end
        expect do
          klass.new.genre.should == 'techno'
        end.to_not raise_error
      end

      it 'should not cause the list of assignable values to be evaluated if the :secondary_default option is not used' do
        klass = Song.disposable_copy do
          assignable_values_for :genre, :default => 'techno' do
            raise "block called!"
          end
        end
        expect do
          klass.new.genre.should == 'techno'
        end.to_not raise_error
      end

    end

    context 'when generating methods to list assignable values' do

      it 'should generate an instance method returning a list of assignable values' do
        klass = Song.disposable_copy do
          assignable_values_for :genre do
            %w[pop rock]
          end
        end
        klass.new.assignable_genres.should == %w[pop rock]
      end

      it 'should call #to_a on the list of assignable values, allowing ranges and scopes to be passed as allowed value descriptors' do
        klass = Song.disposable_copy do
          assignable_values_for :year do
            1999..2001
          end
        end
        klass.new.assignable_years.should == [1999, 2000, 2001]
      end

      it 'should evaluate the value block in the context of the record instance' do
        klass = Song.disposable_copy do
          assignable_values_for :genre do
            genres
          end
          def genres
            %w[pop rock]
          end
        end
        klass.new.assignable_genres.should == %w[pop rock]
      end

      it 'should include a previously saved value, even if is no longer allowed' do
        klass = Song.disposable_copy do
          assignable_values_for :genre do
            %w[pop rock]
          end
        end
        record = klass.create!(:genre => 'pop')
        klass.update_all(:genre => 'ballad') # update without validation for the sake of this test
        record.reload.assignable_genres.should =~ %w[pop rock ballad]
      end

      context 'humanization' do

        context 'legacy methods for API compatibility' do

          it "should define a method #humanized on assignable string values, which return up the value's' translation" do
            klass = Song.disposable_copy do
              assignable_values_for :genre do
                %w[pop rock]
              end
            end
            klass.new.assignable_genres.collect(&:humanized).should == ['Pop music', 'Rock music']
          end
          
          it 'should not define a method #humanized on values that are not strings or boolean' do
            klass = Song.disposable_copy do
              assignable_values_for :year do
                [1999, 2000, 2001]
              end
            end
            years = klass.new.assignable_years
            years.should == [1999, 2000, 2001]
            years.first.should_not respond_to(:humanized)
          end

        end

        it 'should define a method that return pairs of values and their humanization' do
          klass = Song.disposable_copy do
            assignable_values_for :genre do
              %w[pop rock]
            end
          end
          genres = klass.new.humanized_genres
          genres.collect(&:value).should == ['pop', 'rock']
          genres.collect(&:humanized).should == ['Pop music', 'Rock music']
          genres.collect(&:to_s).should == ['Pop music', 'Rock music']
        end

        it 'should use String#humanize as a default translation' do
          klass = Song.disposable_copy do
            assignable_values_for :genre do
              %w[electronic]
            end
          end
          klass.new.humanized_genres.collect(&:humanized).should == ['Electronic']
        end

        it 'should allow to define humanizations for values that are not strings' do
          klass = Song.disposable_copy do
            assignable_values_for :year do
              [1977, 1980, 1983]
            end
          end
          years = klass.new.humanized_years
          years.collect(&:value).should == [1977, 1980, 1983]
          years.collect(&:humanized).should == ['The year a new hope was born', 'The year the Empire stroke back', 'The year the Jedi returned']
        end

        it 'should allow to directly declare humanized values by passing a hash to assignable_values_for' do
          klass = Song.disposable_copy do
            assignable_values_for :genre do
              { 'pop' => 'Pop music', 'rock' => 'Rock music' }
            end
          end
          klass.new.humanized_genres.collect(&:humanized).should =~ ['Pop music', 'Rock music']
        end

        it 'should properly look up humanizations for namespaced models' do
          klass = Recording::Vinyl.disposable_copy do
            assignable_values_for :year do
              [1977, 1980, 1983]
            end
          end
          years = klass.new.humanized_years
          years.collect(&:humanized).should == ['The year a new hope was born', 'The year the Empire stroke back', 'The year the Jedi returned']
        end

      end

      context 'with :through option' do

        it 'should retrieve assignable values from the given method' do
          klass = Song.disposable_copy do
            assignable_values_for :genre, :through => :delegate
            def delegate
              @delegate ||= 'delegate'
            end
          end
          record = klass.new
          record.delegate.should_receive(:assignable_song_genres).and_return %w[pop rock]
          record.assignable_genres.should == %w[pop rock]
        end

        it "should pass the record to the given method if the delegate's query method takes an argument" do
          delegate = Object.new
          def delegate.assignable_song_genres(record)
            record_received(record)
             %w[pop rock]
          end
          klass = Song.disposable_copy do
            assignable_values_for :genre, :through => :delegate
            define_method :delegate do
              delegate
            end
          end
          record = klass.new
          delegate.should_receive(:record_received).with(record)
          record.assignable_genres.should ==  %w[pop rock]
        end

        it 'should raise an error if the given method returns nil' do
          klass = Song.disposable_copy do
            assignable_values_for :genre, :through => :delegate
            def delegate
              nil
            end
          end
          expect { klass.new.assignable_genres }.to raise_error(AssignableValues::DelegateUnavailable)
        end

      end

    end

  end

end
