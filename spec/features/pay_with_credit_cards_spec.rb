require 'spec_helper'

describe "PayWithCreditCards" do
  describe "GET /checkout/payment" do

    let (:user) { create(:user) }

    before(:each) do
      @bogus_payment_method = create(:bogus_payment_method, :display_on => :front_end)
      create(:payment_method, :display_on => :front_end)

      shipping_method = create(:shipping_method)
      Spree::ShippingMethod.stub(:all_available) { [shipping_method] }

      sign_in_as!(user)
    end

    context "no existing cards", :js => true do
      subject { page }

      before do
        create(:product)
        create(:country)
        create(:state)

        Spree::CreditCard.all.map(&:destroy)

        visit spree.products_path

        find(:xpath, "//div[@class='product-image']/a").click
        click_button 'Add To Cart'
        click_button 'Checkout'
        fill_in 'order_bill_address_attributes_firstname', :with => 'Jeff'
        fill_in 'order_bill_address_attributes_lastname', :with => 'Squires'
        fill_in 'order_bill_address_attributes_address1', :with => '123 Foo St'
        fill_in 'order_bill_address_attributes_city', :with => 'Fooville'
        select 'Alabama', :from => 'order_bill_address_attributes_state_id'

        fill_in 'order_bill_address_attributes_zipcode', :with => '12345'
        fill_in 'order_bill_address_attributes_phone', :with => '123-123-1234'
        check "Use Billing Address"

        click_button 'Save and Continue'

        click_button 'Save and Continue'
      end

      it { should_not have_css('table.existing-credit-card-list tbody tr') }

      it { should have_button('Save and Continue') }

      context 'when Credit Card is clicked on' do
        before do
          choose 'Credit Card'
        end

        it { should have_button('Save and Continue') }
      end

      context 'when Credit card is clicked on after Check is clicked on' do
        before do
          choose 'Credit Card'
          choose 'Check'
          choose 'Credit Card'
        end

        it { should have_button('Save and Continue') }
      end

      context 'when Check is clicked on' do
        before do
          choose 'Check'
        end

        it { should have_button('Save and Continue') }
      end
    end

    context "existing cards" do
      before(:each) do

        # set up existing payments with this credit card
        @credit_card = create(:credit_card, :gateway_payment_profile_id => 'FAKE_GATEWAY_ID')

        order = create(:order_in_delivery_state, :user => user, :line_items_count => 1)
        order.update!  # set order.total

        # go to payment state
        order.next
        order.state.should eq('payment')

        # add a payment
        payment = create(:payment, :order => order, :source =>  @credit_card, :amount => order.total, :payment_method => @bogus_payment_method)

        # go to confirm
        order.next
        order.state.should eq('confirm')

        # go to complete
        order.next
        order.state.should eq('complete')

        # capture payment
        order.payments.each(&:capture!)
        order.update!
        order.should_not be_outstanding_balance

        # Add all countries to global zone so that shipping method
        # can be selected during checkout (otherwise a nil object error
        # ocurrs when presenting the shipment in the order summary)
        global_zone = Spree::Zone.first
        Spree::Country.all.each do |country|
          Spree::ZoneMember.create!(zone: global_zone, zoneable: country)
        end
      end

      it "allows an existing credit card to be chosen from list and used for a purchase", js: true do
        visit spree.products_path

        find(:xpath, "//div[@class='product-image']/a").click
        click_button 'Add To Cart'
        click_button 'Checkout'
        fill_in 'order_bill_address_attributes_firstname', :with => 'Jeff'
        fill_in 'order_bill_address_attributes_lastname', :with => 'Squires'
        fill_in 'order_bill_address_attributes_address1', :with => '123 Foo St'
        fill_in 'order_bill_address_attributes_city', :with => 'Fooville'
        # fill_in 'order_bill_address_attributes_state_name', :with => 'Alabama'
        select 'Alabama', :from => 'order_bill_address_attributes_state_id'

        fill_in 'order_bill_address_attributes_zipcode', :with => '12345'
        fill_in 'order_bill_address_attributes_phone', :with => '123-123-1234'
        check "Use Billing Address"

        click_button 'Save and Continue'

        click_button 'Save and Continue'

        page.should have_xpath("//table[@class='existing-credit-card-list']/tbody/tr", :text => @credit_card.last_digits) #, :count => x)
        choose 'existing_card'

        click_button 'Save and Continue'

        page.should have_content "Ending in #{@credit_card.last_digits}"
      end

      it 'allows selecting a different payment method', :js => true do
        visit spree.products_path

        find(:xpath, "//div[@class='product-image']/a").click
        click_button 'Add To Cart'
        click_button 'Checkout'
        fill_in 'order_bill_address_attributes_firstname', :with => 'Jeff'
        fill_in 'order_bill_address_attributes_lastname', :with => 'Squires'
        fill_in 'order_bill_address_attributes_address1', :with => '123 Foo St'
        fill_in 'order_bill_address_attributes_city', :with => 'Fooville'
        select 'Alabama', :from => 'order_bill_address_attributes_state_id'

        fill_in 'order_bill_address_attributes_zipcode', :with => '12345'
        fill_in 'order_bill_address_attributes_phone', :with => '123-123-1234'
        check "Use Billing Address"

        click_button 'Save and Continue'

        click_button 'Save and Continue'

        choose 'use_existing_card_no'
        choose 'use_existing_card_yes'
        choose 'Check'

        click_button 'Save and Continue'

        page.should have_content('Your order has been processed successfully')
      end
    end
  end
end
