//
// AWPagedArray.m
//
// Copyright (c) 2014 Alek Åström
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "AWPagedArray.h"

@implementation AWPagedArray {
    NSUInteger _totalCount;
    NSUInteger _maxObjectsPerPage;
    NSMutableDictionary *_pages;
    
    BOOL _needsUpdateProxiedArray;
    NSArray *_proxiedArray;
}

#pragma mark - Public methods
#pragma mark Initialization
- (instancetype)initWithCount:(NSUInteger)count maxObjectsPerPage:(NSUInteger)maxObjectsPerPage initialPageIndex:(NSInteger)initialPageIndex {
    
    _totalCount = count;
    _maxObjectsPerPage = maxObjectsPerPage;
    _pages = [[NSMutableDictionary alloc] initWithCapacity:[self numberOfPages]];
    _initialPageIndex = initialPageIndex;
    
    return self;
}
- (instancetype)initWithCount:(NSUInteger)count maxObjectsPerPage:(NSUInteger)maxObjectsPerPage {
    return [self initWithCount:count maxObjectsPerPage:maxObjectsPerPage initialPageIndex:1];
}

#pragma mark Accessing data
- (void)setObjects:(NSArray *)objects forPage:(NSUInteger)page {
    
    // Make sure object count is correct
    NSAssert((objects.count <= _maxObjectsPerPage || page == [self _lastPageIndex]), @"Expected object count per page: %ld received: %ld", (unsigned long)_maxObjectsPerPage, (unsigned long)objects.count);
    
    _pages[@(page)] = objects;
    _needsUpdateProxiedArray = YES;
}
- (NSUInteger)pageForIndex:(NSUInteger)index {
    return index/_maxObjectsPerPage + _initialPageIndex;
}
- (NSIndexSet *)indexSetForPage:(NSUInteger)page {
    NSParameterAssert(page < _initialPageIndex+[self numberOfPages]);
    
    NSUInteger rangeLength = _maxObjectsPerPage;
    if (page == [self _lastPageIndex]) {
        rangeLength = (_totalCount % _maxObjectsPerPage) ?: _maxObjectsPerPage;
    }
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange((page - _initialPageIndex) * _maxObjectsPerPage, rangeLength)];
}
- (NSDictionary *)pages {
    return _pages;
}
- (NSUInteger)numberOfPages {
    return ceil((CGFloat)_totalCount/_maxObjectsPerPage);
}

#pragma mark - NSArray overrides
- (id)objectAtIndex:(NSUInteger)index {
    
    id object = [[self _proxiedArray] objectAtIndex:index];
    
    [self.delegate pagedArray:self
              willAccessIndex:index
                 returnObject:&object];
    
    return object;
}
- (id)objectAtIndexedSubscript:(NSUInteger)index {
    return [self objectAtIndex:index];
}

#pragma mark - Proxying
+ (Class)class {
    return [NSArray class];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    
    [anInvocation setTarget:[self _proxiedArray]];
    [anInvocation invoke];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [[self _proxiedArray] methodSignatureForSelector:sel];
}
+ (BOOL)respondsToSelector:(SEL)aSelector {
    
    id proxy = [[[self class] alloc] init];
    return [proxy respondsToSelector:aSelector];
}
- (NSString *)description {
    return [[self _proxiedArray] description];
}

#pragma mark - Private methods
- (NSArray *)_proxiedArray {
    
    if (!_proxiedArray || _needsUpdateProxiedArray) {
        
        [self _generateProxiedArray];
        _needsUpdateProxiedArray = NO;
    }
    
    return _proxiedArray;
}
- (void)_generateProxiedArray {
    
    NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:_totalCount];
    
    for (NSInteger pageIndex = _initialPageIndex; pageIndex < [self numberOfPages]+_initialPageIndex; pageIndex++) {
        
        NSArray *page = _pages[@(pageIndex)];
        if (!page) page = [self _placeholdersForPage:pageIndex];
        
        [objects addObjectsFromArray:page];
    }
    
    _proxiedArray = objects;
}
- (NSArray *)_placeholdersForPage:(NSUInteger)page {
    
    NSMutableArray *placeholders = [[NSMutableArray alloc] initWithCapacity:_maxObjectsPerPage];
    
    NSUInteger pageLimit = [[self indexSetForPage:page] count];
    for (NSUInteger i = 0; i < pageLimit; ++i) {
        [placeholders addObject:[NSNull null]];
    }
    
    return placeholders;
}
- (NSInteger)_lastPageIndex {
    return [self numberOfPages]+_initialPageIndex-1;
}

@end
