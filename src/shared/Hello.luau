local Hello = {}

function Hello.greet(name: string): string
	return ("Hello, %s!"):format(name)
end

return Hello
