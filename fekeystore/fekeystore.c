#include <stdio.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	int i =11;

	printf("\nUser space example: hello world from Fabio&Eduardo\n");
	setbuf(stdout,NULL);
	while (i--) {
		printf("%i ", i);
		sleep(1);
	}
	printf("\nUser space example: goodbye from Fabio&Eduardo\n");

	return(0);
}
