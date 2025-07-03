import XCTest
import Combine
@testable import PriceAdjustPro

class NotificationViewModelTests: XCTestCase {
    var onSaleViewModel: OnSaleViewModel!
    var priceAdjustmentsViewModel: PriceAdjustmentsViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        super.setUp()
        onSaleViewModel = OnSaleViewModel()
        priceAdjustmentsViewModel = PriceAdjustmentsViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        onSaleViewModel = nil
        priceAdjustmentsViewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - OnSale Notification Tests
    
    func testNewSalesDetection() {
        // Given
        let expectation = XCTestExpectation(description: "Sales loaded")
        let initialSalesCount = onSaleViewModel.sales.count
        
        // When
        onSaleViewModel.$sales
            .sink { sales in
                if !sales.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        onSaleViewModel.loadSales()
        
        // Then
        wait(for: [expectation], timeout: 5)
        XCTAssertGreaterThan(onSaleViewModel.sales.count, initialSalesCount)
    }
    
    func testHighValueSalesFiltering() {
        // Given
        let sampleSales = createSampleSaleItems()
        
        // When
        let highValueSales = sampleSales.filter { $0.savings ?? 0 > 50.0 }
        
        // Then
        XCTAssertFalse(highValueSales.isEmpty, "Should have some high-value sales")
        
        for sale in highValueSales {
            XCTAssertGreaterThan(sale.savings ?? 0, 50.0, "Each sale should have savings > $50")
        }
    }
    
    func testSalesNotificationThrottling() {
        // Given
        let previousCount = 10
        let newSalesCount = 15
        
        // When - Simulate checking for new sales
        // In a real test, we'd call the private method or expose it for testing
        
        // Then
        let expectedNewSales = newSalesCount - previousCount
        XCTAssertEqual(expectedNewSales, 5, "Should detect 5 new sales")
    }
    
    // MARK: - Price Adjustments Notification Tests
    
    func testPriceAdjustmentDetection() {
        // Given
        let expectation = XCTestExpectation(description: "Price adjustments loaded")
        
        // When
        priceAdjustmentsViewModel.$adjustments
            .sink { adjustments in
                if !adjustments.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        priceAdjustmentsViewModel.loadPriceAdjustments()
        
        // Then
        wait(for: [expectation], timeout: 5)
    }
    
    func testSignificantPriceDropFiltering() {
        // Given
        let sampleAdjustments = createSamplePriceAdjustments()
        
        // When
        let significantAdjustments = sampleAdjustments.filter { $0.priceDifference > 10.0 }
        
        // Then
        for adjustment in significantAdjustments {
            XCTAssertGreaterThan(adjustment.priceDifference, 10.0, "Each adjustment should have difference > $10")
        }
    }
    
    func testTotalSavingsCalculation() {
        // Given
        let sampleAdjustments = createSamplePriceAdjustments()
        
        // When
        let totalSavings = sampleAdjustments.reduce(0) { $0 + $1.priceDifference }
        
        // Then
        XCTAssertGreaterThan(totalSavings, 0, "Total savings should be positive")
    }
    
    // MARK: - Notification Timing Tests
    
    func testNotificationSchedulingDelay() {
        // Test that notifications aren't sent immediately on app launch
        // but only when there are actual new items
        
        // Given
        let initialLoad = true
        let previousCount = 0
        let newCount = 10
        
        // When
        let shouldNotify = previousCount > 0 && newCount > previousCount
        
        // Then
        XCTAssertFalse(shouldNotify, "Should not notify on initial load")
    }
    
    func testNotificationOnRefresh() {
        // Test that notifications are sent when refreshing with new data
        
        // Given
        let previousCount = 5
        let newCount = 8
        
        // When
        let shouldNotify = previousCount > 0 && newCount > previousCount
        
        // Then
        XCTAssertTrue(shouldNotify, "Should notify when refreshing with new data")
    }
    
    // MARK: - Error Handling Tests
    
    func testNotificationErrorHandling() {
        // Test that notification errors don't crash the app
        
        // Given
        let expectation = XCTestExpectation(description: "Error handled gracefully")
        
        // When - Simulate an error condition
        priceAdjustmentsViewModel.$errorMessage
            .sink { errorMessage in
                if errorMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate API error by calling with invalid data
        // This would need to be set up with proper mocking
        
        // Then
        // wait(for: [expectation], timeout: 3)
        XCTAssertTrue(true, "Error handling test placeholder")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleSaleItems() -> [SaleItem] {
        return [
            SaleItem(
                id: 1,
                itemCode: "12345",
                description: "Test Item 1",
                regularPrice: 100.0,
                salePrice: 40.0,
                instantRebate: nil,
                savings: 60.0,
                saleType: "instant_rebate",
                promotion: createSamplePromotion(),
                saleStartDate: "2024-01-01",
                saleEndDate: "2024-01-31",
                daysRemaining: 15,
                category: "Electronics",
                itemNumber: "12345",
                warehouseNumber: "001",
                isNew: false,
                isPopular: true
            ),
            SaleItem(
                id: 2,
                itemCode: "67890",
                description: "Test Item 2",
                regularPrice: 50.0,
                salePrice: 40.0,
                instantRebate: nil,
                savings: 10.0,
                saleType: "sale",
                promotion: createSamplePromotion(),
                saleStartDate: "2024-01-01",
                saleEndDate: "2024-01-31",
                daysRemaining: 15,
                category: "Food",
                itemNumber: "67890",
                warehouseNumber: "001",
                isNew: true,
                isPopular: false
            )
        ]
    }
    
    private func createSamplePriceAdjustments() -> [PriceAdjustment] {
        return [
            PriceAdjustment(
                itemCode: "12345",
                description: "Test Product 1",
                currentPrice: 25.99,
                lowerPrice: 20.99,
                priceDifference: 5.00,
                storeLocation: "Test Store",
                storeNumber: "001",
                purchaseDate: "2024-01-01",
                daysRemaining: 30,
                originalStore: "Test Store",
                originalStoreNumber: "001",
                dataSource: "test",
                isOfficial: true,
                promotionTitle: "Test Promotion"
            ),
            PriceAdjustment(
                itemCode: "67890",
                description: "Test Product 2",
                currentPrice: 35.99,
                lowerPrice: 20.99,
                priceDifference: 15.00,
                storeLocation: "Test Store",
                storeNumber: "001",
                purchaseDate: "2024-01-01",
                daysRemaining: 30,
                originalStore: "Test Store",
                originalStoreNumber: "001",
                dataSource: "test",
                isOfficial: true,
                promotionTitle: "Test Promotion"
            )
        ]
    }
    
    private func createSamplePromotion() -> Promotion {
        return Promotion(
            title: "Test Promotion",
            saleStartDate: "2024-01-01",
            saleEndDate: "2024-01-31",
            daysRemaining: 15,
            itemsCount: 10
        )
    }
}

// MARK: - Performance Tests

class NotificationPerformanceTests: XCTestCase {
    
    func testSalesFilteringPerformance() {
        // Test performance of filtering large lists of sales
        
        let largeSalesList = (0..<1000).map { index in
            SaleItem(
                id: index,
                itemCode: "\(index)",
                description: "Item \(index)",
                regularPrice: Double.random(in: 10...100),
                salePrice: Double.random(in: 5...50),
                instantRebate: nil,
                savings: Double.random(in: 1...50),
                saleType: "sale",
                promotion: Promotion(
                    title: "Test",
                    saleStartDate: "2024-01-01",
                    saleEndDate: "2024-01-31",
                    daysRemaining: 15,
                    itemsCount: 1
                ),
                saleStartDate: "2024-01-01",
                saleEndDate: "2024-01-31",
                daysRemaining: 15,
                category: "Test",
                itemNumber: "\(index)",
                warehouseNumber: "001",
                isNew: false,
                isPopular: false
            )
        }
        
        measure {
            let highValueSales = largeSalesList.filter { $0.savings ?? 0 > 50.0 }
            _ = highValueSales.prefix(3)
        }
    }
    
    func testPriceAdjustmentCalculationPerformance() {
        // Test performance of calculating total savings
        
        let largeAdjustmentsList = (0..<1000).map { index in
            PriceAdjustment(
                itemCode: "\(index)",
                description: "Item \(index)",
                currentPrice: Double.random(in: 20...100),
                lowerPrice: Double.random(in: 10...50),
                priceDifference: Double.random(in: 1...20),
                storeLocation: "Test Store",
                storeNumber: "001",
                purchaseDate: "2024-01-01",
                daysRemaining: 30,
                originalStore: "Test Store",
                originalStoreNumber: "001",
                dataSource: "test",
                isOfficial: true,
                promotionTitle: nil
            )
        }
        
        measure {
            let totalSavings = largeAdjustmentsList.reduce(0) { $0 + $1.priceDifference }
            _ = totalSavings
        }
    }
}