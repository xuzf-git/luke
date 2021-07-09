local seed = std.parseInt(std.extVar("SEED"));
local batch_size = std.parseInt(std.extVar("BATCH_SIZE"));
local accumulation_steps = std.parseInt(std.extVar("ACCUMULATION_STEPS"));
local train_data_path = std.extVar("TRAIN_DATA_PATH");
local validation_data_path = std.extVar("VALIDATION_DATA_PATH");

local num_epochs = std.parseInt(std.extVar("NUM_EPOCHS"));

local transformers_model_name = std.extVar("TRANSFORMERS_MODEL_NAME");
local tokenizer = {"type": "pretrained_transformer", "model_name": transformers_model_name, "add_special_tokens": true};
local token_indexers = {
            "tokens": {"type": "pretrained_transformer", "model_name": transformers_model_name}
    };

{
    "dataset_reader": {
       "type": "lareqa",
       "mode": "squad",
       "tokenizer": tokenizer,
       "token_indexers": token_indexers},
    "validation_dataset_reader": {
       "type": "lareqa",
       "mode": "squad",
       "tokenizer": tokenizer,
       "token_indexers": token_indexers},
    "train_data_path": train_data_path,
    "validation_data_path": validation_data_path,
    "data_loader": {
        "batch_size": batch_size, "shuffle": true
    },
    "trainer": {
        "num_epochs": num_epochs,
        "patience": 3,
        "cuda_device": -1,
        "grad_norm": 5.0
        ,
        "num_gradient_accumulation_steps": accumulation_steps,
        "checkpointer": {
            "keep_most_recent_by_count": 0
        },
        "validation_metric": "+mAP",
        "optimizer": {
            "type": "adamw",
            "lr": 2e-5,
            "weight_decay": 0.01,
            "parameter_groups": [
                [
                    [
                        "bias",
                        "LayerNorm.weight",
                    ],
                    {
                        "weight_decay": 0
                    }
                ]
            ],
        },
        "learning_rate_scheduler": {
            "type": "custom_linear_with_warmup",
            "warmup_ratio": 0.06
        },
    },
    "random_seed": seed,
    "numpy_seed": seed,
    "pytorch_seed": seed
}
