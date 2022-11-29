module gamer::PaperPaysDiamond{
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self};

    // can not create new game because before game is not expired.
    const EINVALID_TO_CREATE_GAME : u64 = 1;

    // can not withdrawal because expired time is not come.
    const EINVALID_TO_RESOLVE_GAME : u64 = 2;

    // not enough coin
    const EINVALID_BALANCE: u64 = 3;

    // invalid withdraw vector
    const EINVALID_WITHDRAW_VECTOR: u64 = 4;

    // there are fewer than n depositers
    const EWRONG_ENOUGH_DEPOSITERS: u64 = 5;

    // there are full n depositers
    const EWRONG_FULL_DEPOSITERS: u64 = 6;

    // can not deposit because time is expired.
    const EINVALID_TO_DEPOSIT : u64 = 7;

    // can not call function because not owner.
    const EINVALID_OWNER : u64 = 8;

    // not exist game
    const EINVALID_GAME_ADDRESS : u64 = 9;

    struct PaysGame<phantom CoinType> has key{
        members: u64,
        amount: u64,
        withdraw: vector<u64>,
        expired_time: u64,
        active: bool,
        depositers: vector<address>
    }
    struct GameHouse has key {
        creator_ids: vector<address>
    }

    fun init_module(sender: &signer) {
        move_to(sender, GameHouse{
            creator_ids: vector::empty()
        });
    }

    public entry fun create_game<CoinType>(sender: &signer, n: u64, x: u64, withdraw:vector<u64>, t: u64) acquires PaysGame, GameHouse{
        let sender_addr = signer::address_of(sender);
        
        let i = 0;
        let sum = 0;
        while(i < vector::length(&withdraw)){
            sum = sum + *vector::borrow(&withdraw, i);
            i = i + 1;
        };
        assert!(sum == 10000, EINVALID_WITHDRAW_VECTOR);
        if(!exists<PaysGame<CoinType>>(sender_addr)){
            let info_store = PaysGame<CoinType>{
                members: n,
                amount: x,
                withdraw,
                expired_time: t,
                active: false,
                depositers: vector::empty<address>()
            };
            move_to(sender, info_store);
        } else {
            let existing_info_store = borrow_global_mut<PaysGame<CoinType>>(sender_addr);
            assert!(existing_info_store.expired_time < timestamp::now_seconds(), EINVALID_TO_CREATE_GAME);
            existing_info_store.members = n;
            existing_info_store.amount = x;
            existing_info_store.withdraw = withdraw;
            existing_info_store.expired_time = t;
            existing_info_store.active = false;
            existing_info_store.depositers = vector::empty<address>();
        };
        let game_house = borrow_global_mut<GameHouse>(@gamer);
        if(!vector::contains(&game_house.creator_ids, &sender_addr)){
            vector::push_back(&mut game_house.creator_ids, sender_addr);
        };
    }

    public entry fun deposit<CoinType>(sender: &signer, game_address: address) acquires PaysGame, GameHouse {
        let sender_addr = signer::address_of(sender);
        let game_house = borrow_global_mut<GameHouse>(@gamer);
        assert!(vector::contains(&game_house.creator_ids, &game_address), EINVALID_GAME_ADDRESS);
        let existing_info_store = borrow_global_mut<PaysGame<CoinType>>(game_address);
        assert!(existing_info_store.expired_time > timestamp::now_seconds(), EINVALID_TO_DEPOSIT);
        assert!(!existing_info_store.active, EWRONG_FULL_DEPOSITERS);
        assert!(coin::balance<CoinType>(sender_addr) > existing_info_store.amount, EINVALID_BALANCE);
        let coins = coin::withdraw<CoinType>(sender, existing_info_store.amount);
        coin::deposit(@gamer, coins);
        vector::push_back(&mut existing_info_store.depositers, sender_addr);
        if(vector::length(&existing_info_store.depositers) == existing_info_store.members) {
            existing_info_store.active = true;
        };
    }

    public entry fun resovle<CoinType>(sender: &signer, game_address: address) acquires PaysGame, GameHouse {
        assert!(signer::address_of(sender) == @gamer, EINVALID_OWNER);
        let game_house = borrow_global_mut<GameHouse>(@gamer);
        assert!(vector::contains(&game_house.creator_ids, &game_address), EINVALID_GAME_ADDRESS);
        let existing_info_store = borrow_global_mut<PaysGame<CoinType>>(game_address);
        assert!(existing_info_store.expired_time < timestamp::now_seconds(), EINVALID_TO_RESOLVE_GAME);
        if(existing_info_store.active){
            let i = 0;
            while(i < vector::length(&existing_info_store.withdraw)){
                let withdraw_all_amount = existing_info_store.members * existing_info_store.amount;
                let amount = withdraw_all_amount * *vector::borrow(&existing_info_store.withdraw, i) / 10000;
                coin::transfer<CoinType>(sender, *vector::borrow(&existing_info_store.depositers, i), amount);
                i = i + 1;
            };
        }
        else {
            let i = 0;
            while(i < vector::length(&existing_info_store.withdraw)){
                let amount = existing_info_store.amount;
                coin::transfer<CoinType>(sender, *vector::borrow(&existing_info_store.depositers, i), amount);
                i = i + 1;
            };
        };
        existing_info_store.active = false;
    }
}