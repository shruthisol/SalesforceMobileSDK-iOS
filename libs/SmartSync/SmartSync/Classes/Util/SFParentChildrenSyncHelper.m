/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SFSyncTarget+Internal.h"
#import "SFParentChildrenSyncHelper.h"
#import <SmartStore/SFSmartStore.h>

@implementation SFParentChildrenSyncHelper

NSString * const kSFParentChildrenRelationshipMasterDetail = @"MASTER_DETAIL";
NSString * const kSFParentChildrenRelationshipLookup = @"LOOKUP";

#pragma mark - String to/from enum for query type

+ (SFParentChildrenRelationshipType) relationshipTypeFromString:(NSString*)relationshipType {
    if ([relationshipType isEqualToString:kSFParentChildrenRelationshipMasterDetail]) {
        return SFParentChildrenRelationpshipMasterDetail;
    } else {
        return SFParentChildrenRelationpshipLookup;
    }
}

+ (NSString*) relationshipTypeToString:(SFParentChildrenRelationshipType)relationshipType {
    switch (relationshipType) {
        case SFParentChildrenRelationpshipMasterDetail:  return kSFParentChildrenRelationshipMasterDetail;
        case SFParentChildrenRelationpshipLookup: return kSFParentChildrenRelationshipLookup;
    }
}

+ (NSString*) getDirtyRecordIdsSql:(SFParentInfo*)parentInfo childrenInfo:(SFChildrenInfo*)childrenInfo parentFieldToSelect:(NSString*)parentFieldToSelect {
    return [NSString stringWithFormat:@"SELECT DISTINCT {%@:%@} FROM {%@} WHERE {%@:%@} = 1 OR EXISTS (SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = {%@:%@} AND {%@:%@} = 1)",
            parentInfo.soupName, parentFieldToSelect, parentInfo.soupName, parentInfo.soupName, kSyncTargetLocal,
            childrenInfo.soupName, childrenInfo.idFieldName, childrenInfo.soupName, childrenInfo.soupName, childrenInfo.parentIdFieldName, parentInfo.soupName, parentInfo.idFieldName, childrenInfo.soupName, kSyncTargetLocal
    ];
}

+ (NSString*) getNonDirtyRecordIdsSql:(SFParentInfo*)parentInfo childrenInfo:(SFChildrenInfo*)childrenInfo parentFieldToSelect:(NSString*)parentFieldToSelect {
    return [NSString stringWithFormat:@"SELECT DISTINCT {%@:%@} FROM {%@} WHERE {%@:%@} = 0 AND NOT EXISTS (SELECT {%@:%@} FROM {%@} WHERE {%@:%@} = {%@:%@} AND {%@:%@} = 1)",
            parentInfo.soupName, parentFieldToSelect, parentInfo.soupName, parentInfo.soupName, kSyncTargetLocal,
            childrenInfo.soupName, childrenInfo.idFieldName, childrenInfo.soupName, childrenInfo.soupName, childrenInfo.parentIdFieldName, parentInfo.soupName, parentInfo.idFieldName, childrenInfo.soupName, kSyncTargetLocal
    ];
}

+ (void)saveRecordTreesToLocalStore:(SFSmartSyncSyncManager *)syncManager target:(SFSyncTarget *)target parentInfo:(SFParentInfo *)parentInfo childrenInfo:(SFChildrenInfo *)childrenInfo recordTrees:(NSArray *)recordTrees {
    NSMutableArray * parentRecords = [NSMutableArray new];
    NSMutableArray * childrenRecords = [NSMutableArray new];
    for (NSDictionary * recordTree  in recordTrees) {

        // XXX should be done in one transaction
        NSMutableDictionary * parent = [recordTree mutableCopy];

        // Separating parent from children
        NSArray * children = parent[childrenInfo.sobjectTypePlural];
        [parent removeObjectForKey:childrenInfo.sobjectTypePlural];
        [parentRecords addObject:parent];

        // Put server id of parent in children
        if (children) {
            for (NSDictionary * child in children) {
                NSMutableDictionary * updatedChild = [child mutableCopy];
                updatedChild[childrenInfo.parentIdFieldName] = parent[parentInfo.idFieldName];
                [childrenRecords addObject:updatedChild];
            }
        }
    }

    // Saving parents
    [target cleanAndSaveInSmartStore:syncManager.store soupName:parentInfo.soupName records:parentRecords];

    // saving children
    [target cleanAndSaveInSmartStore:syncManager.store soupName:childrenInfo.soupName records:childrenRecords];
}

@end