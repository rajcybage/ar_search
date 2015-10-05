require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "an ActiveRecord model which includes PgSearch" do

  with_model :ar_search_model do
    table do |t|
      t.string 'title'
      t.text 'content'
    end

    model do
      include ArSearch
    end
  end

  describe ".ar_search_scope" do
    it "builds a scope" do
      ar_search_model.class_eval do
        ar_search_scope "matching_query", :against => []
      end

      lambda {
        ar_search_model.scoped({}).matching_query("foo").scoped({})
      }.should_not raise_error
    end

    it "builds a scope for searching on a particular column" do
      ar_search_model.class_eval do
        ar_search_scope :search_content, :against => :content
      end

      included = ar_search_model.create!(:content => 'foo')
      excluded = ar_search_model.create!(:content => 'bar')

      results = ar_search_model.search_content('foo')
      results.should include(included)
      results.should_not include(excluded)
    end

    it "builds a scope for searching on multiple columns" do
      ar_search_model.class_eval do
        ar_search_scope :search_text_and_content, :against => [:title, :content]
      end

      included = [
        ar_search_model.create!(:title => 'foo', :content => 'bar'),
        ar_search_model.create!(:title => 'bar', :content => 'foo')
      ]
      excluded = [
        ar_search_model.create!(:title => 'foo', :content => 'foo'),
        ar_search_model.create!(:title => 'bar', :content => 'bar')
      ]

      results = ar_search_model.search_text_and_content('foo bar')

      results.should =~ included
      excluded.each do |result|
        results.should_not include(result)
      end
    end

    it "builds a scope for searching on multiple columns where one is NULL" do
      ar_search_model.class_eval do
        ar_search_scope :search_text_and_content, :against => [:title, :content]
      end

      included = ar_search_model.create!(:title => 'foo', :content => nil)

      results = ar_search_model.search_text_and_content('foo')

      results.should == [included]
    end

    context "when passed a lambda" do
      it "builds a dynamic scope" do
        ar_search_model.class_eval do
          ar_search_scope :search_title_or_content, lambda { |query, pick_content|
            {
              :match => query.gsub("-remove-", ""),
              :against => pick_content ? :content : :title
            }
          }
        end

        included = ar_search_model.create!(:title => 'foo', :content => 'bar')
        excluded = ar_search_model.create!(:title => 'bar', :content => 'foo')

        ar_search_model.search_title_or_content('fo-remove-o', false).should == [included]
        ar_search_model.search_title_or_content('b-remove-ar', true).should == [included]
      end
    end
  end

  describe "a given ar_search_scope" do
    before do
      ar_search_model.class_eval do
        ar_search_scope :search_content, :against => [:content]
      end
   end

    it "allows for multiple space-separated search terms" do
      included = [
        ar_search_model.create!(:content => 'foo bar'),
        ar_search_model.create!(:content => 'bar foo'),
        ar_search_model.create!(:content => 'bar foo baz'),
      ]
      excluded = [
        ar_search_model.create!(:content => 'foo'),
        ar_search_model.create!(:content => 'foo baz')
      ]

      results = ar_search_model.search_content('foo bar')
      results.should =~ included
      results.should_not include(excluded)
    end

  end

end
