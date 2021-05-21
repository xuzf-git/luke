local seed = std.parseInt(std.extVar("SEED"));
local batch_size = std.parseInt(std.extVar("BATCH_SIZE"));
local accumulation_steps = std.parseInt(std.extVar("ACCUMULATION_STEPS"));
local train_data_path = std.extVar("TRAIN_DATA_PATH");
local validation_data_path = std.extVar("VALIDATION_DATA_PATH");

local num_epochs = std.parseInt(std.extVar("NUM_EPOCHS"));
local num_steps_per_epoch = std.parseInt(std.extVar("NUM_STEPS_PER_EPOCH"));

local transformers_model_name = std.extVar("TRANSFORMERS_MODEL_NAME");

{
    "dataset_reader": {
       "type": "transformer_squad",
       "transformer_model_name": transformers_model_name,
       },
    "train_data_path": train_data_path,
    "validation_data_path": validation_data_path,
    "data_loader": {
        "batch_size": batch_size,
        "shuffle": true,
        "num_workers": 1,
        "max_instances_in_memory": 50000
    },
     "validation_data_loader": {
        "batch_size": batch_size, "shuffle": false, "num_workers": 1,
        "max_instances_in_memory": 5000
    },
    "model": {
        "type": "transformer_qa",
        "transformer_model_name": transformers_model_name
    },
    "trainer": {
        "num_epochs": num_epochs,
        "patience": 3,
        "cuda_device": -1,
        "grad_norm": 5.0
        ,
        "num_gradient_accumulation_steps": accumulation_steps,
        "checkpointer": {
            "num_serialized_models_to_keep": 0
        },
        "validation_metric": "-loss",
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
            "type": "linear_with_warmup",
            "warmup_steps": std.floor(num_steps_per_epoch * num_epochs / 10),
            "num_epochs": num_epochs,
            "num_steps_per_epoch": num_steps_per_epoch
        },
    },
    "random_seed": seed,
    "numpy_seed": seed,
    "pytorch_seed": seed
}
