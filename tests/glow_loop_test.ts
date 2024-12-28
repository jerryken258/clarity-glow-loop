import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can list a new item",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('glow_loop', 'list-item', [
                types.ascii("Old Chair"),
                types.ascii("Wooden chair for upcycling"),
                types.ascii("furniture")
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        let getItem = chain.mineBlock([
            Tx.contractCall('glow_loop', 'get-item-details', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        const item = getItem.receipts[0].result.expectOk().expectSome();
        assertEquals(item['status'], types.ascii("available"));
    }
});

Clarinet.test({
    name: "Can claim and complete transaction",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // List item
        let block = chain.mineBlock([
            Tx.contractCall('glow_loop', 'list-item', [
                types.ascii("Old Chair"),
                types.ascii("Wooden chair for upcycling"),
                types.ascii("furniture")
            ], deployer.address)
        ]);
        
        // Claim item
        let claimBlock = chain.mineBlock([
            Tx.contractCall('glow_loop', 'claim-item', [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        claimBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Complete transaction
        let completeBlock = chain.mineBlock([
            Tx.contractCall('glow_loop', 'complete-transaction', [
                types.uint(0)
            ], deployer.address)
        ]);
        
        completeBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check user stats
        let statsBlock = chain.mineBlock([
            Tx.contractCall('glow_loop', 'get-user-stats', [
                types.principal(deployer.address)
            ], deployer.address)
        ]);
        
        const stats = statsBlock.receipts[0].result.expectOk();
        assertEquals(stats['recycling-credits'], types.uint(10));
        assertEquals(stats['reputation-score'], types.uint(105));
    }
});