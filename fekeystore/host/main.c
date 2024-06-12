#include <err.h>
#include <stdio.h>
#include <string.h>

#include <tee_client_api.h>

#include <fekeystore_ta.h>

/* TEE resources */
struct test_ctx {
	TEEC_Context ctx;
	TEEC_Session sess;
};

void prepare_tee_session(struct test_ctx *ctx)
{
	TEEC_UUID uuid = TA_FEKEYSTORE_UUID;
	uint32_t origin;
	TEEC_Result res;

	/* Initialize a context connecting us to the TEE */
	res = TEEC_InitializeContext(NULL, &ctx->ctx);
	if (res != TEEC_SUCCESS)
		errx(1, "TEEC_InitializeContext failed with code 0x%x", res);

	/* Open a session with the TA */
	res = TEEC_OpenSession(&ctx->ctx, &ctx->sess, &uuid,
			       TEEC_LOGIN_PUBLIC, NULL, NULL, &origin);
	if (res != TEEC_SUCCESS)
		errx(1, "TEEC_Opensession failed with code 0x%x origin 0x%x",
			res, origin);
}

void terminate_tee_session(struct test_ctx *ctx)
{
	TEEC_CloseSession(&ctx->sess);
	TEEC_FinalizeContext(&ctx->ctx);
}

static TEEC_Result write_object(struct test_ctx *ctx, char *id, char *data, size_t data_len)
{
	TEEC_Operation op;
	uint32_t origin;
	TEEC_Result res;
	size_t id_len = strlen(id);

	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT,
					 TEEC_MEMREF_TEMP_INPUT,
					 TEEC_NONE, TEEC_NONE);

	op.params[0].tmpref.buffer = id;
	op.params[0].tmpref.size = id_len;

	op.params[1].tmpref.buffer = data;
	op.params[1].tmpref.size = data_len;

	res = TEEC_InvokeCommand(&ctx->sess, TA_FEKEYSTORE_CMD_WRITE_OBJECT, &op, &origin);
	if (res != TEEC_SUCCESS)
		printf("Command WRITE_RAW failed: 0x%x / %u\n", res, origin);

	switch (res) {
	case TEEC_SUCCESS:
		break;
	default:
		printf("Command WRITE_RAW failed: 0x%x / %u\n", res, origin);
	}

	return res;
}

#define TEST_OBJECT_SIZE	7000

int main(void)
{
	struct test_ctx ctx;
	char obj1_id[] = "object#1";		/* string identification for the object */
	char obj1_data[TEST_OBJECT_SIZE];
	TEEC_Result res;

	printf("Prepare session with the TA\n");
	prepare_tee_session(&ctx);

	/*
	 * Create object, read it, delete it.
	 */
	printf("\nTest on object \"%s\"\n", obj1_id);
	printf("- Create and load object in the TA secure storage\n");
	memset(obj1_data, 0x42, sizeof(obj1_data));

	res = write_object(&ctx, obj1_id, obj1_data, sizeof(obj1_data));
	if (res != TEEC_SUCCESS)
		errx(1, "Failed to create an object in the secure storage");

	printf("\nWe're done, close and release TEE resources\n");
	terminate_tee_session(&ctx);
	return 0;
}