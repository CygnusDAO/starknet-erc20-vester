pub mod contracts {
    pub mod snake_erc20_vesting;
    pub mod camel_erc20_vesting;
    pub mod interface;
}

pub mod errors {
    pub mod token_vesting_errors;
}

pub mod types {
    pub mod token_vesting_types;
}

pub mod events {
    pub mod token_vesting_events;
}

pub mod mock {
    pub mod snake_erc20;
    pub mod camel_erc20;
}
