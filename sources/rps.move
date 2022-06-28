address admin {
module GameShowdown {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use StarcoinFramework::Event;
    use SFC::PseudoRandom;

    struct Bank<phantom T: store> has store, key {
        bank: Token::Token<T>
    }

    struct CheckEvent has store, drop {
        amount: u128,
        result: bool,
        input: bool,
        token_type: Token::TokenCode
    }

    struct BankEvent<phantom T: store> has store, key {
        check_event: Event::EventHandle<CheckEvent>,
    }

    /// @admin init bank 管理员初始化银行
    public(script) fun init_bank<TokenType: store>(signer: signer, amount: u128) {
        let account = &signer;
        let signer_addr = Signer::address_of(account);

        assert!(signer_addr == @admin, 10003);
        assert!(! exists<Bank<TokenType>>(signer_addr), 10004);
        assert!(Account::balance<TokenType>(signer_addr) >= amount, 10005);

        let token = Account::withdraw<TokenType>(account, amount);
        move_to(account, Bank<TokenType>{
            bank: token
        });

        move_to(account, BankEvent<TokenType>{
            check_event: Event::new_event_handle<CheckEvent>(account),
        });
    }

    /// @admin withdraw from bank 管理员从银行提款
    public(script) fun withdraw<TokenType: store>(signer: signer, amount: u128) acquires Bank {
        let signer_addr = Signer::address_of(&signer);

        assert!(signer_addr == @admin, 10003);
        assert!(exists<Bank<TokenType>>(signer_addr), 10004);

        let bank = borrow_global_mut<Bank<TokenType>>(signer_addr);
        let token = Token::withdraw<TokenType>(&mut bank.bank, amount);
        Account::deposit<TokenType>(signer_addr, token);
    }

    /// everyone can deposit amount to bank 任何人从银行中提款
    public(script) fun deposit<TokenType: store>(signer: signer, amount: u128)  acquires Bank {
        assert!(exists<Bank<TokenType>>(@admin), 10004);

        let token = Account::withdraw<TokenType>(&signer, amount);
        let bank = borrow_global_mut<Bank<TokenType>>(@admin);
        Token::deposit<TokenType>(&mut bank.bank, token);
    }

    // 玩家赢
    fun win_token<TokenType: store>(signer: signer, amount: u128) acquires Bank {
        let bank = borrow_global_mut<Bank<TokenType>>(@admin);
        let token = Token::withdraw<TokenType>(&mut bank.bank, amount);
        Account::deposit<TokenType>(Signer::address_of(&signer), token);
    }

    // 玩家输
    fun loss_token<TokenType: store>(signer: signer, amount: u128) acquires Bank {
        let token = Account::withdraw<TokenType>(&signer, amount);
        let bank = borrow_global_mut<Bank<TokenType>>(@admin);
        Token::deposit<TokenType>(&mut bank.bank, token);
    }

    // 从 0 1 2 中随机获取一个数
    fun getRandBool(): bool {
        PseudoRandom::rand_u64(&@admin) % 3
    }

    /// check game result 获得游戏结果
    public(script) fun check<TokenType: store>(account: signer, amount: u128, input: bool) acquires Bank, BankEvent {
        let signer_addr = Signer::address_of(&account);

        //  check account amount
        assert!(Account::balance<TokenType>(signer_addr) > amount, 1);

        // can't all in @admin balance  max only   1/10  every times
        assert!(Token::value<TokenType>(&borrow_global<Bank<TokenType>>(@admin).bank) >= amount * 10, 2);

        // 0 => 剪刀
        // 1 => 石头
        // 2 => 布
        let player = getRandBool();
        let robot = getRandBool();

        if (robot == player) {
            // 这个地方需要把钱从银行中返回到玩家原地址
        } else {
            // [0-2, 1-0, 2-1] player win

            if (player == 0 && robot == 2 || player == 1 && robot == 0 || player == 2 && robot == 1) {
                win_token<TokenType>(account, amount)
            } else {
                loss_token<TokenType>(account, amount)
            }
        }

        // event
        let bank_event = borrow_global_mut<BankEvent<TokenType>>(@admin);
        Event::emit_event(&mut bank_event.check_event, CheckEvent{
            amount,
            result,
            input,
            token_type: Token::token_code<TokenType>()
        });
    }
}
}